# Demo Application: BookStore App services on K8S 

Follows micro-services approach. Run locally using docker-compose and traefik as loadbalancer/proxy; and on Kubernetes (DigitalOcean Managed).

> ## Announcement: Course on Kubernetes
> If you're want to start deploying your containers to Kubernetes, especially on AWS EKS, [check this course on Kubernetes](https://courses.devteds.com/kubernetes-get-started) that walkthrough creating Kubernetes cluster on AWS EKS using Terraform and deploying multiple related containers applications to Kubernetes and more. https://courses.devteds.com/kubernetes-get-started

![DemoStoreAppArchitecture](https://github.com/devteds/demo-app-bookstore/blob/master/doc/demo-app-architecture.png)

## Code directory

```
mkdir -p ~/proj
cd ~/proj
git clone git@github.com:devteds/demo-apps-on-k8s.git
```

## Run locally

```
cd ~/proj/demo-apps-on-k8s/local

# one time
docker network create demoapp

docker-compose up
# on a separate terminal window
docker-compose ps
```

Once `shopapi` is up, run schema migration script and seed some test data

```
docker-compose exec shopapi rails db:migrate
docker-compose exec shopapi rails db:seed
```

Once all the services start up,

```
open http://localhost
```

- http://localhost => routes to `website` service
- Clicking on `Shop` goes to http://localhost/shop => routes to `shopui` service
- Shopping page calls http://localhost/api/books => routes to `shopapi` service


**Note:** You may change the port mapping if port 80 is taken on dev machine


## On Kubernetes

Create Kubernetes cluster on DigitalOcean

### DigitalOcean API Token

Signup/Login to DigitalOcean and genereate API Token

### Create Kubernetes Cluster

```
cd ~/proj/demo-apps-on-k8s/infra
cp secret.auto.example.tfvars secret.auto.tfvars
# edit to assign DigitalOcean API token and save
```

Optionally edit `main.tf` as needed. For example, if you need to change the region or number of worker nodes or kubernetes version

```
terraform init
terraform plan
terraform apply
```

You may login to DigitalOcean and verify Kubernetes status.

Update `kubeconfig` for `kubectl`

```
mkdir -p ~/.kube
terraform output config > ~/.kube/config
```

Verify Kubernetes cluster status

```
kubectl get nodes
kubectl version
# this must give you both client and server version. Client is kubectl. Server is K8S api server
```

### Service 1: Website

```
cd ~/proj/demo-apps-on-k8s

kubectl apply -f services/website/deploy.yaml
kubectl get deploy
kubectl get po

kubectl apply -f services/website/service.yaml
kubectl get svc
kubectl describe svc/website
```

Verify using port-forward

```
kubectl port-forward svc/website 8082:80
open http://localhost:8082
```

### Service 2: Shopping API

Install database

```
helm install bookstore stable/mysql --set mysqlUser=appuser,mysqlPassword=appuser123,mysqlDatabase=bookstore

kubectl get  svc -l app=bookstore-mysql
kubectl get  po -l app=bookstore-mysql
kubectl get  deploy -l app=bookstore-mysql
```

Verify

```
kubectl run -i --tty mysql-client --image=devteds/mysql-client:5.7_b1 --restart=Never -- bash -il

mysql -uappuser -pappuser123 -hbookstore-mysql bookstore
> show tables;
> show databases;
> exit

mysql -uappuser -pappuser123 -hbookstore-mysql.default.svc.cluster.local bookstore
> exit
```

Configs & Secrets

```
kubectl apply -f services/shopapi/config.yaml
kubectl get cm
kubectl describe cm/shopapi-cm

kubectl apply -f services/shopapi/secret.yaml
kubectl get secret/shopapi-sec -o yaml
```

Database schema script - use Job

```
kubectl create -f services/shopapi/job-dbc.yaml
kubectl get job -l app=shopapi-db
kubectl describe job/shopapi-job-dbc

# delete job when complete
kubectl delete job/shopapi-job-dbc
```

Deployment & Service

```
kubectl apply -f services/shopapi/deploy.yaml
kubectl get po -l app=shopapi

kubectl apply -f services/shopapi/service.yaml
kubectl get svc -l app=shopapi
```

Verify

```
kubectl port-forward svc/shopapi 3200:3000
open http://localhost:3200/api/books
```

### Service 3: Shopping UI

Deploy & Service

```
kubectl apply -f services/shopui/deploy.yaml
kubectl get po -l app=shopui

kubectl apply -f services/shopui/service.yaml
kubectl get svc -l app=shopui
```

You may verify using port forward but let's to integrated test using ingress

### Ingress Controller

****Install controller:** install Ingress controller

```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.26.1/deploy/static/mandatory.yaml
```

Create loadbalancer services which will create LB instance on DigitialOcean and route http/https traffic to the ingress controller pod created above.

```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.26.1/deploy/static/provider/cloud-generic.yaml
```

Verify

```
kubectl get pods --all-namespaces -l app.kubernetes.io/name=ingress-nginx
kubectl get svc --namespace=ingress-nginx
```

Runs a service and triggers a new loadbalancer IP of which will be assigned to this service as an external IP. Notice the type of this service is LoadBalancer.

Give it a minute or so and try again,

```
kubectl get svc/ingress-nginx -n ingress-nginx

NAME            TYPE           CLUSTER-IP       EXTERNAL-IP         PORT(S)                      AGE
ingress-nginx   LoadBalancer   10.245.203.250   <LoadBalancer IP>   80:31323/TCP,443:32325/TCP   2m
```

Verify the loadbalancer on Cloud provider web console. On Digital Ocean, under `Networking > Loadbalancers`. 

## Ingress resource

Ingress resource is where we define the routing requirments and rules


```
kubectl apply -f route/ingress.yaml
kubectl get ing
```

```
LB_IP=$(kubectl get svc/ingress-nginx -n ingress-nginx | grep ingress | awk '{print $4}')
echo $LB_IP

# website
open http://$LB_IP

# shopapi
open http://$LB_IP/api/books
open http://$LB_IP/api/books/1
```

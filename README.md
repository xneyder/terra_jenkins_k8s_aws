# AWS + Terraform + Kubernetes + Jenkins + CLoudFront + nodejs


![meow](![meow](https://github.com/xneyder/terra_jenkins_k8s_aws/blob/master/diagram.png)

The purpose of this project is to design and implement a continuous delivery architecture for a scalable and secure 3 tier Node application.

The proposed solution is to serve the application using a kubernetes cluster having the following resources:

### 1. web
- Deployment with 2 replicas and a connection to the api NodePort described in the next resource.
- In the web index we use a cloudfront cdn to serve the nyan.gif image.
- NodePort Service.
 
### 2. api
- Deployment with 2 replicas and a connection to the postgres ClusterIp described in the next resource.
- NodePort Service.

### 3. postgress
- Deployment with 1 replica.
- cronjon to backup the postgres database every 24 hours and save the dump to s3
- ClusterIp Service.
- Persistent Volume Claim so data will not be lost after restarts

### 4. jenkins
- Deployment with 1 replica.
- dind image so the jenkins image is able to build docker images
- Jenkins periodically pulls the code from gitlab and if there is a new commit it starts a CI/CD pipeline. 
  This job builds the docker images and using helm deploys them to a kubernetes test cluster, then executes tests on it and if they pass and then user accepts they are deployed to production.
  By default deployments in kubernetes are done using Rolling Update, so there is not down time for the application.
- NodePort Service
- Persistent Volume Claim so data will not be lost after restarts

### 5. flluentd
- DaemonSet to collect logs from all kubernetes nodes and save them to CloudWatch


All the infrastructure is defined using Terraform.

# Wordpress on AWS ECS cluster using MySQL RDS database
This little project aims to build "ready to use" wordpress image on an ECS cluster that will use a MySQL RDS as a database.




# What you have done ?



How run your project

AWS free trial has been used to build this project.
AWS account and credentials have been configured through the AWS CLI. 
aws_profile is the name of the configured profile in the AWS CLI.

Terraform, Packer, Ansible and Docker should be installed in order to run this project

The following tools have been used :

- Packer HashiCorp for building the Docker Image and upload it to ECR registry
- Terraform HashiCorp for provisioning AWS underlying infrastructure
- Ansible for provisioning the Docker Image and installing Wordpress
- Alpine Linux has been used as a base image 

*** Provision the AWS Infrastructure ***

All the required code is aws_underlying_infrastructure folder

1- Clone the repo
  git clone repo_url
  
2- Update secrets.tfvars file with the right values, specify the aws_profile configured in AWS CLI
3- Update the configuration.tfvars file and ensure that the specified values are all suitable
4- Run terraform apply command with -var-file option:

terraform apply  -var-file=secrets.tfvar -var-file=configuration.tfvars

5- Take note of the output variables once the terraform built is done, especially the ECR registry URL and the ALB DNS.

terraform output
 
6- In order to destroy all the AWS indrastructure, just run 

terraform destroy  -var-file=secrets.tfvar -var-file=configuration.tfvars


*** Build the Wordpress Docker image ***


All the required code is wordpress-deployment folder

 1- Update your own variables.json file with the aws_profile configured in AWS CLI and the ECR registry URL displayed in the output of previous terraform provision (remove the repository name).
 
 2- Run packer build -var-file=variables.json wordpress_template.json
 
Once the packer build is done, open the ALB dns_name, diaplayed also in terraform output, in any browser and you should see the Wordpress installation website.

 

# What are the components interact between each over

The AWS components used to provision the AWS infrastructure and configure the Wordpress service are as following:

 
- VPC (ip address range of /16)
- Internet gateway (interface between VPC and the internet).
- Three public subnet (/24) in 3 availability zone without the need of NAT gateways.
- Route tables and route tables association for the three subnets.
- Security groups for restricting traffic as much as possible and ensuring internal communication between the ALB, ECS and RDS on the     right ports.
- IAM policies, roles and IAM instance profile.
- ECS container instances in different availability zones in public subnet with auto scaling group configured and security group,         running ECS agent ( created from the latest ecs-optimized linux AMI).
- ECS attached security group allows outbound traffic to the RDS DB instance on port 3306.
- ALB to distribute traffic between container instances with security group allowing HTTP incoming traffic on port 80
- MySQL RDS database instance
- ECR repository to be used to upload the Wordpress Docker images then it will be used from docker engine running on ECS instances to      pull the images.
- Wordpress service task definition.

	
I opted for a simple, Highly Available and secure AWS architecture.
I have created VPC with 3 public subnets in 3 different availability zones in eu-wes-1 (Ireland) region.
The public subnets hare all attached to a routing table that points to the Internet Gateway, in order to provide internet connectivity. 
An internet-facing ALB security group (alb-sg) that allows incoming traffic on port 80 (HTTP) and outbound traffic only  from the ECS instance security group (ecs-instance-sg).
The ECS security group (ecs-instance-sg) handles incoming traffic only from the ALB and it allows all outgoing traffic. An outbound rule allows traffic to RDS instance security group on port 3306. 
A single MySQL RDS instance has been created with security group (rds-sg) that only permits incoming traffic from the ECS instance secur group (ecs-instance-sg) on port 3306.

The ALB has been created to load balance the http request to EC2 container instances on port 80 across the three AZs.
A http health check has been used in the Target Group to register the healthy EC2 instances.
The output of terraform provisioning dispalys the ALB public dns name (load_balancer_dns_name) that should be used later in the deployment of wordpress docker image.

Two IAM roles have been created: one for the ECS instances and another one for the ECS services. 
ECS instances role has the suitable permissions to interact with ECS Cluster in order to register itself when a server started. 
ECS services role has the permissions in order to be able to register/unregister services from ALB, etc.
The Container instances need to be launched with an EC2 instance IAM role. 
AWS RDS service has been used to provision MySQL database for Wordpress.
The output of terraform provisioning dispalys the RDS instance endpoint (wordpress_db_endpoint). 

The ECS Container instances are managed inside an Auto-scaling group with a desired capacity of 2 instances.
The Wordpress setup is defined through a TaskDefinition and deployed as an ECS service. 
An awslogs Docker logging driver has been used to publish ECS docker logs to Cloudwatch.



The Wordpress will be running with PHP7 (through php-fpm) and nginx. 
The approach chosen for this project will be based on one-container.
This means one container can run per instance per port.
The s6-overlay has been used as the process supervisor for php-fpm and nginx.
The required s6, nginx, php and wordperss roles and packages will be installed via an ansible playbook during the deployment of the wordpress docker image. 


In order to build the Docker Image, an ansible provisioner has been used through Packer.
The Docker Image needs python to be installed and the shadow package for creating the required users. 
The docker builder is based on Alpine Linux as a base image. 
As the mentionned python and shadow packages are not installed by default on Alpine Linux, a shell provisioner is run which installs all of them, before running the ansible provisioner.
Then another shell provisiooner will run to remove the necessary packages and delete the unused ansible files in order to save some space in the final wordpress docker image.

The nginx and php-fpm worker processes will not run as root users. 
That's why the web root directory should have the proper permissions set. 
This is done on the container startup by s6-overlay.
The (wp-config.php) file has been modified in order to accept the different environment variables for the most important configuration parameters so it is well suited to run in a containerized environment.

The Packer template used for this project uses the user variables. The  variables.json file should be updated with the aws_profile configured in AWS CLI and the ECR registry URL.
The docker post-processor should generate a tagged image and then upload it to ECR regpository.
The docker engines running on the ECS instances will pull it from the ECR repository once the packer built is done. 



# What problems did you have

I work rarely with Packer, I had some issues to start building my wordpress docker image but it was a nice opportunity to learn and practice it 
I had some issues while applying terraform due to dependencies between the different AWS components.
Sometimes, it is very tough to find the root cuase of the problem due to the lack of details provided by AWS when using Terraform.


# How you would have done things to have the best HA/automated architecture

I have deployed the ECS instances across three different AZs in order to ensure HA and Fault Tolerance. 
ALB has been used to balance traffic between different AZs. 
Different AWS services used for this project such as: ECS, EC2, ALB, VPC are natively designed by amazon for HA and FT. 
Terraform has been used to provision and build the whole AWS infrastructure in a fully autoamted way.
Ansible a powerful configuration management tool has been used to deploy the wordpress docker image using a playbook.


# Share with us any ideas you have in mind to improve this kind of infrastructure.

The current configuration uses Docker volumes for the web root volume. 
This is not convenient for production environment and could be improved. Whenever the Wordpress docker image is moved to a different instance (or deleted) the Wordpress files (wp-content and other modifications) will be lost.
As the data still stored in the RDS DB instance, the wordpress site could be corrupted.
The setup also limits the deployment to only one wordpress docker container without ensuring the horizontal scalability.
EFS service could be used as a shared file-system ato host a mounted voume for the web root. I have never done this before but this choice could be suitable.
The EFS Filesystem backups should be activated in this scenario. 

The choice made for MySQL RDS instance could be improved for production scenario. 
In prod environment, the RDS should be configured with Multi-AZs instance with provisioned IOPS and a backupà running in specific maitenance windows and even read-replicas to improve performance reads. 
We have to think to use Aurora as it will perform better than RDS. 

Logs of all AWS components should be centrally gathered, managed and easily accessible. 
Both AWS infrastructure and application metrics have to be collected and visualized for performance tracking. 

The configuuration used for NGINX and PHP could be optimized and improved for production env. 

The wordpress configuration also could be improved by configuring a caching service (thinkof AWS ElastiCache) and storing the sessions in a DB. 
AWS CloudFront, as a CDN solution, could be used to serve the static content. 

The website is exposed in HTTP, this must be changed by using HTTPS and configurin SSL certificates on the ALB with the AWS Certificate Manager.

All the most sensitive information is updated to Wordpress through environment variables. 
This is a big security concern. we have to deploy a secrets management solution such as HashiCorp Vault and use it to protect and store the sensitive data.


When several devops team members work on the same infrastructure with terraform, securing  and managing the Terraform state file becomes a big challenge to overcome.  
We have to use the state locking as a built-in solution provided y terraform in order to lock the state operations that could write state.
This prevents others from acquiring the lock and potentially corrupting the production state.

We have to add also description and tags for better readability and visibilty to AWS compoenents.


# Some considerations before pushing the project to Production

Pushing to Production any project should be done with Confidence !
All the above mentionned improvements should be taken into account


- Secrets management
- Terraform state management
- Web root file system + scheduled backups
- SSL termination
- Production-ready RDS database
- Production-ready PHP & nginx configuration
- Production-ready instance types for the ECS instances
- Auto-scaling
- Wordpress optimization, caching, and CDN
- Logs management and monitoring
- Route 53 for domains and multi-region availability.
   




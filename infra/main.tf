terraform {
  required_version = ">= 0.12.0"
}

provider "aws" {
  version = ">= 2.11"
  region  = var.region
}

provider "random" {
  version = "~> 2.1"
}

provider "local" {
  version = "~> 1.2"
}

provider "null" {
  version = "~> 2.1"
}

provider "template" {
  version = "~> 2.1"
}

provider "external" {}

provider "helm" {
  kubernetes {
    config_path = "/home/ec2-user/.kube/config"
  }
}

data "aws_availability_zones" "available" {
}

locals {
  cluster_name = "xneyder-cluster"
}

locals {
  s3_origin_id = "S3Origin"
}


resource "random_string" "suffix" {
  length  = 8
  special = false
}

#Create EKS
resource "null_resource" "eks" {
  provisioner "local-exec" {
    command = "eksctl create cluster --name ${local.cluster_name} --nodegroup-name standard-workers --node-type t2.medium --nodes 8 --nodes-min 8 --nodes-max 16 --node-ami auto --node-private-networking"
  }
  provisioner "local-exec" {
    when    = "destroy"
    command = "sleep 30; eksctl delete cluster --name ${local.cluster_name}"
  }
#  depends_on = [module.vpc]
}

#Get the EKS Role
data "external" "eks-role" {
  program    = ["bash", "./scripts/get_eks_role.sh"]
  depends_on = [null_resource.eks]
}


#Attach policy to EKS Role for fluentd
resource "aws_iam_role_policy" "k8s-logs" {
  name = "Logs-Policy-For-Worker"
  role = data.external.eks-role.result.role_name

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "logs:DescribeLogGroups",
                "logs:DescribeLogStreams",
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "*",
            "Effect": "Allow"
        }
    ]

}
EOF
}

#Create managed policy
resource "aws_iam_policy" "ALBIngressControllerIAMPolicy" {
  name        = "ALBIngressControllerIAMPolicy"
  path        = "/"
  description = "ALB Ingress Controller IAM policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "acm:DescribeCertificate",
        "acm:ListCertificates",
        "acm:GetCertificate"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:CreateSecurityGroup",
        "ec2:CreateTags",
        "ec2:DeleteTags",
        "ec2:DeleteSecurityGroup",
        "ec2:DescribeAccountAttributes",
        "ec2:DescribeAddresses",
        "ec2:DescribeInstances",
        "ec2:DescribeInstanceStatus",
        "ec2:DescribeInternetGateways",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSubnets",
        "ec2:DescribeTags",
        "ec2:DescribeVpcs",
        "ec2:ModifyInstanceAttribute",
        "ec2:ModifyNetworkInterfaceAttribute",
        "ec2:RevokeSecurityGroupIngress"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:AddListenerCertificates",
        "elasticloadbalancing:AddTags",
        "elasticloadbalancing:CreateListener",
        "elasticloadbalancing:CreateLoadBalancer",
        "elasticloadbalancing:CreateRule",
        "elasticloadbalancing:CreateTargetGroup",
        "elasticloadbalancing:DeleteListener",
        "elasticloadbalancing:DeleteLoadBalancer",
        "elasticloadbalancing:DeleteRule",
        "elasticloadbalancing:DeleteTargetGroup",
        "elasticloadbalancing:DeregisterTargets",
        "elasticloadbalancing:DescribeListenerCertificates",
        "elasticloadbalancing:DescribeListeners",
        "elasticloadbalancing:DescribeLoadBalancers",
        "elasticloadbalancing:DescribeLoadBalancerAttributes",
        "elasticloadbalancing:DescribeRules",
        "elasticloadbalancing:DescribeSSLPolicies",
        "elasticloadbalancing:DescribeTags",
        "elasticloadbalancing:DescribeTargetGroups",
        "elasticloadbalancing:DescribeTargetGroupAttributes",
        "elasticloadbalancing:DescribeTargetHealth",
        "elasticloadbalancing:ModifyListener",
        "elasticloadbalancing:ModifyLoadBalancerAttributes",
        "elasticloadbalancing:ModifyRule",
        "elasticloadbalancing:ModifyTargetGroup",
        "elasticloadbalancing:ModifyTargetGroupAttributes",
        "elasticloadbalancing:RegisterTargets",
        "elasticloadbalancing:RemoveListenerCertificates",
        "elasticloadbalancing:RemoveTags",
        "elasticloadbalancing:SetIpAddressType",
        "elasticloadbalancing:SetSecurityGroups",
        "elasticloadbalancing:SetSubnets",
        "elasticloadbalancing:SetWebACL"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:CreateServiceLinkedRole",
        "iam:GetServerCertificate",
        "iam:ListServerCertificates"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "waf-regional:GetWebACLForResource",
        "waf-regional:GetWebACL",
        "waf-regional:AssociateWebACL",
        "waf-regional:DisassociateWebACL"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "tag:GetResources",
        "tag:TagResources"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "waf:GetWebACL"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

#Put policy in EKS role
resource "aws_iam_role_policy_attachment" "ALBIngressControllerIAMPolicy-attach" {
  role       = data.external.eks-role.result.role_name
  policy_arn = "${aws_iam_policy.ALBIngressControllerIAMPolicy.arn}"
}

#create log group for fluentd
resource "aws_cloudwatch_log_group" "kubernetes" {
  name = "kubernetes"
}

#create log group for eks
resource "aws_cloudwatch_log_group" "eks_logs" {
  name = "/aws/eks/${local.cluster_name}/cluster"
}

#resource "aws_ecr_repository" "top-api" {
#  name = "top-api"
#}
#resource "aws_ecr_repository" "top-web" {
#  name = "top-web"
#}
#resource "aws_ecr_repository" "top-pgbackup" {
#  name = "top-pgbackup"
#}
#resource "aws_ecr_repository" "top-jenkins" {
#  name = "top-jenkins"
#}

#resource "null_resource" "web-docker" {
#  provisioner "local-exec" {
#    command = "bash ./scripts/build_docker.sh ../src/web/Dockerfile ../src/web/ ${aws_ecr_repository.top-web.repository_url}"
#  }
#  depends_on = [aws_ecr_repository.top-web]
#}

#resource "null_resource" "api-docker" {
#  provisioner "local-exec" {
#    command = "bash ./scripts/build_docker.sh ../src/api/Dockerfile ../src/api/ ${aws_ecr_repository.top-api.repository_url}"
#  }
#  depends_on = [aws_ecr_repository.top-api]
#}

#resource "null_resource" "jenkins-docker" {
#  provisioner "local-exec" {
#    command = "bash ./scripts/build_docker.sh ../src/jenkins/Dockerfile ../src/jenkins/ ${aws_ecr_repository.top-jenkins.repository_url}"
#  }
#  depends_on = [aws_ecr_repository.top-jenkins]
#}


#resource "null_resource" "pgbackup-docker" {
#  provisioner "local-exec" {
#    command = "bash ./scripts/build_docker.sh ../src/pgbackup/Dockerfile ../src/pgbackup/ ${aws_ecr_repository.top-pgbackup.repository_url}"
#  }
#  depends_on = [aws_ecr_repository.top-pgbackup]
#}

#Bucket to hold postgres backups
resource "aws_s3_bucket" "pgbackup" {
  bucket        = "pgbackup.xneyder.${var.domain_name}"
  acl           = "private"
  force_destroy = true

  versioning {
    enabled = true
  }

  tags = {
    Name = "pgbackup"
  }
}

#Source Bucket for CloudFront
resource "aws_s3_bucket" "cdn" {
  bucket = "cdn.xneyder.${var.domain_name}"
  acl    = "public-read"

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::cdn.xneyder.${var.domain_name}/*"
        }
    ]
}
EOF 
}

#Add nyan image to bucket for cloudfront
resource "aws_s3_bucket_object" "nyan" {
  bucket = "${aws_s3_bucket.cdn.bucket}"
  key    = "nyan.gif"
  source = "files/nyan.gif"
  acl    = "public-read"
  depends_on = [aws_s3_bucket.cdn]
}

#Create ACM certificate
resource "aws_acm_certificate" "cert" {
  domain_name       = "*.${var.domain_name}"
  validation_method = "DNS"
}

#Route 53 zone
data "aws_route53_zone" "zone" {
  name         = "${var.domain_name}."
  private_zone = false
}

#Record to validdate ACM
resource "aws_route53_record" "cert_validation" {
  name    = "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_name}"
  type    = "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_type}"
  zone_id = "${data.aws_route53_zone.zone.id}"
  records = ["${aws_acm_certificate.cert.domain_validation_options.0.resource_record_value}"]
  ttl     = 60
}

#ACM used in CloudFront
resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = "${aws_acm_certificate.cert.arn}"
  validation_record_fqdns = ["${aws_route53_record.cert_validation.fqdn}"]
}

# Create Cloudfront distribution
resource "aws_cloudfront_distribution" "cdn_distribution" {
  origin {
    domain_name = "${aws_s3_bucket.cdn.bucket}.s3.amazonaws.com"
    origin_id   = "S3-${aws_s3_bucket.cdn.bucket}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "match-viewer"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }
  # By default, show index.html file
  default_root_object = "index.html"
  enabled             = true

  # If there is a 404, return index.html with a HTTP 200 Response
  custom_error_response {
    error_caching_min_ttl = 3000
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
  }

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.cdn.bucket}"

    # Forward all query strings, cookies and headers
    forwarded_values {
      query_string = true
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Distributes content to US and Europe
  # price_class = "PriceClass_100"

  # Restricts who is able to access this content
  restrictions {
    geo_restriction {
      # type of restriction, blacklist, whitelist or none
      restriction_type = "none"
    }
  }

  aliases = ["cdn.${var.domain_name}"]
  # SSL certificate for the service.
  viewer_certificate {
    #    cloudfront_default_certificate = true
    acm_certificate_arn = aws_acm_certificate.cert.arn
    ssl_support_method  = "sni-only"
  }
  depends_on = [aws_acm_certificate_validation.cert]
}

#CloudFront CNAME
resource "aws_route53_record" "cloudfront_cname" {
  name    = "cdn.${var.domain_name}"
  type    = "CNAME"
  zone_id = "${data.aws_route53_zone.zone.id}"
  records = ["${aws_cloudfront_distribution.cdn_distribution.domain_name}"]
  ttl     = 60
}


#Give permissions in EKS
resource "null_resource" "k8s-rbac" {
  provisioner "local-exec" {
    command = "kubectl apply -f ../k8s/rbac-role.yaml"
  }
  depends_on = [null_resource.kubectl-init]
}

#Install the alb ingress controller in EKS
resource "null_resource" "alb-ingress-controller" {
  provisioner "local-exec" {
    command = "kubectl apply -f ../k8s/alb-ingress-controller.yaml"
  }
  depends_on = [aws_iam_role_policy.k8s-logs,aws_iam_role_policy_attachment.ALBIngressControllerIAMPolicy-attach,null_resource.k8s-rbac]
}

#Init Helm
resource "null_resource" "helm-init" {
  provisioner "local-exec" {
    command = "helm init --service-account tiller --history-max 200"
  }
#  provisioner "local-exec" {
#    when = "destroy"
#    command = "helm reset --force"
#  }
  depends_on = [null_resource.k8s-rbac,null_resource.pgpassword,null_resource.pgpassword-test,null_resource.awsaccesskey,null_resource.awssecretaccesskey]
}

#Init kubectl
resource "null_resource" "kubectl-init" {
  provisioner "local-exec" {
    command = "aws eks --region ${var.region} update-kubeconfig --name ${local.cluster_name}"
  }
  depends_on = [null_resource.eks]
}

#Install incubator repo for fuentd helm chart
data "helm_repository" "incubator" {
  name       = "incubator"
  url        = "http://storage.googleapis.com/kubernetes-charts-incubator"
  depends_on = [null_resource.helm-init]
}

#install fluentd for monitoring the cluster
resource "helm_release" "fluentd-cloudwatch" {
  name       = "fluentd-cloudwatch"
  repository = "${data.helm_repository.incubator.metadata.0.name}"
  chart      = "fluentd-cloudwatch"

  set {
    name  = "awsRole"
    value = data.external.eks-role.result.role_name
  }
  set {
    name  = "awsRegion"
    value = var.region
  }
  set {
    name  = "rbac.create"
    value = true
  }
  #set {
  #    name  = "data.fluent.conf"
  #    value = "${file("fluent.conf")}"
  #}
  depends_on = [null_resource.helm-init]
}

#Install postgress
resource "null_resource" "postgres" {
  provisioner "local-exec" {
    command = "helm install --name postgres ../helm/postgres"
  }
  provisioner "local-exec" {
    when = "destroy"
    command = "helm delete --purge postgres"
  }
  depends_on = [null_resource.helm-init]
}

#Install postgress in the test namespace
resource "null_resource" "postgres-test" {
  provisioner "local-exec" {
    command = "helm install --name postgres-test ../helm/postgres --namespace test"
  }
  provisioner "local-exec" {
    when = "destroy"
    command = "helm delete --purge postgres-test"
  }
  depends_on = [null_resource.test_namespace]
}


#install api
resource "null_resource" "api" {
  provisioner "local-exec" {
    command = "helm install --name api ../helm/api"
  }
  provisioner "local-exec" {
    when = "destroy"
    command = "helm delete --purge api"
  }
  depends_on = [null_resource.postgres]
}

#install api in the test namespace
resource "null_resource" "api-test" {
  provisioner "local-exec" {
    command = "helm install --name api-test ../helm/api --namespace test -f ../helm/api/values_test.yaml"
  }
  provisioner "local-exec" {
    when = "destroy"
    command = "helm delete --purge api-test"
  }
  depends_on = [null_resource.postgres-test]
}

#install web
resource "null_resource" "web" {
  provisioner "local-exec" {
    command = "helm install --name web ../helm/web"
  }
  provisioner "local-exec" {
    when = "destroy"
    command = "helm delete --purge web"
  }
  depends_on = [null_resource.api]
}

#install web in the test namespace
resource "null_resource" "web-test" {
  provisioner "local-exec" {
    command = "helm install --name web-test ../helm/web --namespace test -f ../helm/web/values_test.yaml"
  }
  provisioner "local-exec" {
    when = "destroy"
    command = "helm delete --purge web-test"
  }
  depends_on = [null_resource.api-test]
}

#install ingress
resource "null_resource" "ingress" {
  provisioner "local-exec" {
    command = "sleep 120;helm install --name ingress ../helm/ingress"
  }
  provisioner "local-exec" {
    when = "destroy"
    command = "helm delete --purge ingress"
  }
  depends_on = [null_resource.web]
}


#install ingress in the test namespace
resource "null_resource" "ingress-test" {
  provisioner "local-exec" {
    command = "sleep 120;helm install --name ingress-test ../helm/ingress --namespace test -f ../helm/ingress/values_test.yaml"
  }
  provisioner "local-exec" {
    when = "destroy"
    command = "helm delete --purge ingress-test"
  }
  depends_on = [null_resource.web-test]
}

#install jenkins
resource "null_resource" "jenkins" {
  provisioner "local-exec" {
    command = "helm install --name jenkins ../helm/jenkins"
  }
  provisioner "local-exec" {
    when = "destroy"
    command = "helm delete --purge jenkins"
  }
  depends_on = [null_resource.api]
}

#create the test namespace
resource "null_resource" "test_namespace" {
  provisioner "local-exec" {
    command = "kubectl create namespace test"
  }
  provisioner "local-exec" {
    when    = "destroy"
    command = "kubectl delete namespace test"
  }
  depends_on = [null_resource.k8s-rbac]
}

#Create the secrets
resource "null_resource" "pgpassword" {
  provisioner "local-exec" {
    command = "kubectl create secret generic pgpassword --from-literal PGPASSWORD=${var.pgpassword}"
  }
  provisioner "local-exec" {
    when    = "destroy"
    command = "kubectl delete secret pgpassword"
  }
  depends_on = [null_resource.k8s-rbac]
}

resource "null_resource" "pgpassword-test" {
  provisioner "local-exec" {
    command = "kubectl create secret generic pgpassword --from-literal PGPASSWORD=${var.pgpassword} --namespace test"
  }
  provisioner "local-exec" {
    when    = "destroy"
    command = "kubectl delete secret pgpassword --namespace test"
  }
  depends_on = [null_resource.test_namespace]
}

resource "null_resource" "awsaccesskey" {
  provisioner "local-exec" {
    command = "kubectl create secret generic awsaccesskey --from-literal AWS_ACCESS_KEY_ID=${var.awsaccesskey}"
  }
  provisioner "local-exec" {
    when    = "destroy"
    command = "kubectl delete secret awsaccesskey"
  }
  depends_on = [null_resource.k8s-rbac]
}

resource "null_resource" "awssecretaccesskey" {
  provisioner "local-exec" {
    command = "kubectl create secret generic awssecretaccesskey --from-literal AWS_SECRET_ACCESS_KEY=${var.awssecretaccesskey}"
  }
  provisioner "local-exec" {
    when    = "destroy"
    command = "kubectl delete secret awssecretaccesskey"
  }
  depends_on = [null_resource.k8s-rbac]
}


#production dns aliases
data "external" "elb" {
  program    = ["bash", "./scripts/get_elb.sh", "ingress", "default"]
  depends_on = [null_resource.ingress]
}

resource "aws_route53_record" "web_alias" {
  zone_id    = "${data.aws_route53_zone.zone.id}"
  name       = "web.${var.domain_name}"
  type       = "A"

  alias {
    name                   = "${data.external.elb.result.elb_name}"
    zone_id                = "${data.external.elb.result.zone_id}"
    evaluate_target_health = true
  }
  depends_on = [data.external.elb]
}

resource "aws_route53_record" "api_alias" {
  zone_id    = "${data.aws_route53_zone.zone.id}"
  name       = "api.${var.domain_name}"
  type       = "A"

  alias {
    name                   = "${data.external.elb.result.elb_name}"
    zone_id                = "${data.external.elb.result.zone_id}"
    evaluate_target_health = true
  }
  depends_on = [data.external.elb]
}

resource "aws_route53_record" "jenkins_alias" {
  zone_id    = "${data.aws_route53_zone.zone.id}"
  name       = "jenkins.${var.domain_name}"
  type       = "A"

  alias {
    name                   = "${data.external.elb.result.elb_name}"
    zone_id                = "${data.external.elb.result.zone_id}"
    evaluate_target_health = true
  }
  depends_on = [data.external.elb]
}


#test dns aliases
data "external" "elb_test" {
  program    = ["bash", "./scripts/get_elb.sh", "ingress-test", "test"]
  depends_on = [null_resource.ingress-test]
}

resource "aws_route53_record" "web_test_alias" {
  zone_id    = "${data.aws_route53_zone.zone.id}"
  name       = "test.web.${var.domain_name}"
  type       = "A"

  alias {
    name                   = "${data.external.elb_test.result.elb_name}"
    zone_id                = "${data.external.elb_test.result.zone_id}"
    evaluate_target_health = true
  }
  depends_on = [data.external.elb_test]
}

resource "aws_route53_record" "api_test_alias" {
  zone_id    = "${data.aws_route53_zone.zone.id}"
  name       = "test.api.${var.domain_name}"
  type       = "A"

  alias {
    name                   = "${data.external.elb_test.result.elb_name}"
    zone_id                = "${data.external.elb_test.result.zone_id}"
    evaluate_target_health = true
  }
  depends_on = [data.external.elb_test]
}


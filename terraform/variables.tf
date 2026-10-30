variable "aws_region" { 
  type = string
  default = "ap-south-1" 
  }
variable "project_name" { 
  type = string
  default = "talentflow" 
  }
variable "vpc_cidr" { 
  type = string
  default = "10.0.0.0/16" 
  }
variable "container_image" { 
  type = string
  description = "Full ECR image URI, e.g. ACCOUNT.dkr.ecr.ap-south-1.amazonaws.com/talentflow-api:latest" 
  }
variable "db_username" { 
  type = string
  default = "talentflowadmin" 
  }
variable "db_password" { 
  type = string
  sensitive = true
  description = "Supply with TF_VAR_db_password; never commit it." 
  }
variable "app_secret_key" { 
  type = string
  sensitive = true
  description = "Random long Flask/JWT secret; supply with TF_VAR_app_secret_key." 
  }
variable "db_instance_class" { 
  type = string
  default = "db.t3.micro" 
  }
variable "enable_nat_gateway" { 
  type = bool
  default = true
  description = "NAT Gateway incurs ongoing cost. Disable only if you provide private connectivity to required AWS services." 
  }
variable "desired_count" { 
  type = number
  default = 2 
  }
variable "domain_name" { 
  type = string
  default = ""
  description = "Optional Route 53 hosted zone domain already owned by you; leave blank to use ALB DNS." 
  }

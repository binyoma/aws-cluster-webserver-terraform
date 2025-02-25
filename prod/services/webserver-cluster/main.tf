provider "aws" {
  access_key                  = "test"
  secret_key                  = "test"
  region                      = "us-east-1"
  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    s3             = "http://s3.localhost.localstack.cloud:4566"
    dynamodb       = "http://localhost:4566"
    rds            = "http://localhost:4566"
    autoscaling    = "http://localhost:4566"
    ec2            = "http://localhost:4566"
    elb            = "http://localhost:4566"
    elbv2          = "http://localhost:4566"
  }
}
module "webserver_cluster" {
  source = "../../../modules/services/webserver-cluster"
  cluster_name = "webservers-prod"
  db_remote_state_bucket = "terraform"
  db_remote_state_key = "prod/data-stores/mysql/terraform.tfstate"
  instance_type = "m4.large"
  max_size = 10
  min_size = 2
}
resource "aws_autoscaling_schedule" "scale_out_during_business_hours" {
  autoscaling_group_name = module.webserver_cluster.asg_name
  scheduled_action_name  = "scale-out-during-business-hours"
  min_size = 2
  max_size = 10
  desired_capacity = 10
  recurrence = "0 9 * * *"
}
resource "aws_autoscaling_schedule" "scale_in_at_night" {
  autoscaling_group_name = module.webserver_cluster.asg_name
  scheduled_action_name  = "scale-in-at-night"
  min_size = 2
  max_size = 10
  desired_capacity = 2
  recurrence = "0 17 * * *"
}
terraform {
  backend "s3" {
    bucket = "terraform"
    key = "prod/services/webserver-cluster/terraform.tfstate"
    region = "us-east-1"
    dynamodb_table = "terraform_locks"
    encrypt = true

    endpoints                   = {
      s3 = "http://s3.localhost.localstack.cloud:4566"
    }
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    force_path_style            = true
    access_key                  = "test"
    secret_key                  = "test"
  }
}
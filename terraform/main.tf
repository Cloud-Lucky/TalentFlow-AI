data "aws_availability_zones" "available" { state = "available" }
data "aws_caller_identity" "current" {}
locals {
  name = var.project_name
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
  common_tags = { Project = "TalentFlow-AI", ManagedBy = "Terraform", Environment = "learning" }
}
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = merge(local.common_tags, { Name = "${local.name}-vpc" })
}
resource "aws_internet_gateway" "main" { vpc_id = aws_vpc.main.id
  tags = merge(local.common_tags, { Name = "${local.name}-igw" }) }
resource "aws_subnet" "public" {
  count = 2
  vpc_id = aws_vpc.main.id
  availability_zone = local.azs[count.index]
  cidr_block = cidrsubnet(var.vpc_cidr, 8, count.index + 1)
  map_public_ip_on_launch = true
  tags = merge(local.common_tags, { Name = "${local.name}-public-${count.index + 1}" })
}
resource "aws_subnet" "app" {
  count = 2
  vpc_id = aws_vpc.main.id
  availability_zone = local.azs[count.index]
  cidr_block = cidrsubnet(var.vpc_cidr, 8, count.index + 11)
  tags = merge(local.common_tags, { Name = "${local.name}-app-private-${count.index + 1}" })
}
resource "aws_subnet" "db" {
  count = 2
  vpc_id = aws_vpc.main.id
  availability_zone = local.azs[count.index]
  cidr_block = cidrsubnet(var.vpc_cidr, 8, count.index + 21)
  tags = merge(local.common_tags, { Name = "${local.name}-db-private-${count.index + 1}" })
}
resource "aws_route_table" "public" { vpc_id = aws_vpc.main.id
  tags = merge(local.common_tags, { Name = "${local.name}-public-rt" }) }
resource "aws_route" "public_default" { route_table_id = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.main.id }
resource "aws_route_table_association" "public" { count = 2
  subnet_id = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id }
resource "aws_eip" "nat" { count = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"
  tags = merge(local.common_tags, { Name = "${local.name}-nat-eip" }) }
resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id = aws_subnet.public[0].id
  depends_on = [aws_internet_gateway.main]
  tags = merge(local.common_tags, { Name = "${local.name}-nat" })
}
resource "aws_route_table" "app" { count = 2
  vpc_id = aws_vpc.main.id
  tags = merge(local.common_tags, { Name = "${local.name}-app-rt-${count.index + 1}" }) }
resource "aws_route" "app_default" {
  count = var.enable_nat_gateway ? 2 : 0
  route_table_id = aws_route_table.app[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.main[0].id
}
resource "aws_route_table_association" "app" { count = 2
  subnet_id = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.app[count.index].id }
resource "aws_route_table" "db" { vpc_id = aws_vpc.main.id
  tags = merge(local.common_tags, { Name = "${local.name}-db-rt" }) }
resource "aws_route_table_association" "db" { count = 2
  subnet_id = aws_subnet.db[count.index].id
  route_table_id = aws_route_table.db.id }

resource "aws_security_group" "alb" {
  name = "${local.name}-alb-sg"
  description = "Public HTTPS/HTTP entry"
  vpc_id = aws_vpc.main.id
  ingress { from_port = 80
  to_port = 80
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"] }
  ingress { from_port = 443
  to_port = 443
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"] }
  egress { from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"] }
  tags = local.common_tags
}
resource "aws_security_group" "app" {
  name = "${local.name}-app-sg"
  description = "Only ALB can reach app"
  vpc_id = aws_vpc.main.id
  ingress { from_port = 5000
  to_port = 5000
  protocol = "tcp"
  security_groups = [aws_security_group.alb.id] }
  egress { from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"] }
  tags = local.common_tags
}
resource "aws_security_group" "db" {
  name = "${local.name}-db-sg"
  description = "PostgreSQL only from application"
  vpc_id = aws_vpc.main.id
  ingress { from_port = 5432
  to_port = 5432
  protocol = "tcp"
  security_groups = [aws_security_group.app.id] }
  egress { from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"] }
  tags = local.common_tags
}

resource "aws_s3_bucket" "resumes" { bucket_prefix = "${local.name}-resumes-"
  force_destroy = false
  tags = local.common_tags }
resource "aws_s3_bucket_public_access_block" "resumes" {
  bucket = aws_s3_bucket.resumes.id
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_server_side_encryption_configuration" "resumes" {
  bucket = aws_s3_bucket.resumes.id
  rule { apply_server_side_encryption_by_default { sse_algorithm = "AES256" } }
}
resource "aws_s3_bucket_versioning" "resumes" { bucket = aws_s3_bucket.resumes.id
  versioning_configuration { status = "Enabled" } }

resource "aws_db_subnet_group" "main" { name = "${local.name}-db-subnets"
  subnet_ids = aws_subnet.db[*].id
  tags = local.common_tags }
resource "aws_db_instance" "main" {
  identifier = "${local.name}-postgres"
  engine = "postgres"
    instance_class = var.db_instance_class
  allocated_storage = 20
  max_allocated_storage = 50
  db_name = "talentflow"
  username = var.db_username
  password = var.db_password
  db_subnet_group_name = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible = false
  storage_encrypted = true
  backup_retention_period = 7
  skip_final_snapshot = true
  deletion_protection = false
  apply_immediately = true
  tags = local.common_tags
}

resource "aws_sqs_queue" "resume_dlq" {
  name = "${local.name}-resume-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled = true
  tags = local.common_tags
}
resource "aws_sqs_queue" "resume" {
  name = "${local.name}-resume-queue"
  visibility_timeout_seconds = 180
  message_retention_seconds = 345600
  sqs_managed_sse_enabled = true
  redrive_policy = jsonencode({ deadLetterTargetArn = aws_sqs_queue.resume_dlq.arn, maxReceiveCount = 3 })
  tags = local.common_tags
}
resource "aws_sns_topic" "notifications" { name = "${local.name}-notifications"
  tags = local.common_tags }
resource "aws_cloudwatch_log_group" "app" { name = "/ecs/${local.name}-api"
  retention_in_days = 14
  tags = local.common_tags }
resource "aws_cloudwatch_event_bus" "main" { name = "${local.name}-events"
  tags = local.common_tags }

resource "aws_ecr_repository" "api" {
  name = "${local.name}-api"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "AES256" }
  tags = local.common_tags
}
resource "aws_ecs_cluster" "main" { name = "${local.name}-cluster"
  tags = local.common_tags }
resource "aws_iam_role" "task_execution" {
  name = "${local.name}-task-execution"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" }, Action = "sts:AssumeRole" }] })
  tags = local.common_tags
}
resource "aws_iam_role_policy_attachment" "task_execution" { role = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy" }
resource "aws_iam_role" "task" {
  name = "${local.name}-task-role"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" }, Action = "sts:AssumeRole" }] })
  tags = local.common_tags
}
resource "aws_iam_role_policy" "task_access" {
  name = "${local.name}-task-access"
  role = aws_iam_role.task.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["s3:PutObject", "s3:GetObject"], Resource = "${aws_s3_bucket.resumes.arn}/resumes/*" },
    { Effect = "Allow", Action = ["sqs:SendMessage"], Resource = aws_sqs_queue.resume.arn },
    { Effect = "Allow", Action = ["events:PutEvents"], Resource = aws_cloudwatch_event_bus.main.arn },
    { Effect = "Allow", Action = ["sns:Publish"], Resource = aws_sns_topic.notifications.arn }
  ] })
}
resource "aws_lb" "main" {
  name = "${local.name}-alb"
  internal = false
  load_balancer_type = "application"
  subnets = aws_subnet.public[*].id
  security_groups = [aws_security_group.alb.id]
  tags = local.common_tags
}
resource "aws_lb_target_group" "api" {
  name = "${local.name}-api-tg"
  port = 5000
  protocol = "HTTP"
  vpc_id = aws_vpc.main.id
  target_type = "ip"
  health_check { enabled = true
  path = "/health"
  matcher = "200"
  interval = 30
  healthy_threshold = 2
  unhealthy_threshold = 3 }
  tags = local.common_tags
}
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port = 80
  protocol = "HTTP"
  default_action { type = "forward"
  target_group_arn = aws_lb_target_group.api.arn }
}
resource "aws_ecs_task_definition" "api" {
  family = "${local.name}-api"
  network_mode = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu = "512"
  memory = "1024"
  execution_role_arn = aws_iam_role.task_execution.arn
  task_role_arn = aws_iam_role.task.arn
  container_definitions = jsonencode([{
    name = "api", image = var.container_image, essential = true,
    portMappings = [{ containerPort = 5000, hostPort = 5000, protocol = "tcp" }],
    environment = [
      { name = "S3_BUCKET", value = aws_s3_bucket.resumes.bucket },
      { name = "SQS_RESUME_QUEUE_URL", value = aws_sqs_queue.resume.url }, { name = "EVENT_BUS_NAME", value = aws_cloudwatch_event_bus.main.name },
      { name = "DATABASE_URL", value = "postgresql+psycopg://${var.db_username}:${var.db_password}@${aws_db_instance.main.address}:5432/talentflow" },
      { name = "SECRET_KEY", value = var.app_secret_key }, { name = "JWT_SECRET_KEY", value = var.app_secret_key },
      { name = "CORS_ORIGINS", value = "*" }
    ],
    logConfiguration = { logDriver = "awslogs", options = { "awslogs-group" = aws_cloudwatch_log_group.app.name, "awslogs-region" = var.aws_region, "awslogs-stream-prefix" = "api" } }
  }])
}
resource "aws_ecs_service" "api" {
  name = "${local.name}-api"
  cluster = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count = var.desired_count
  launch_type = "FARGATE"
  health_check_grace_period_seconds = 90
  network_configuration { subnets = aws_subnet.app[*].id
  security_groups = [aws_security_group.app.id]
  assign_public_ip = false }
  load_balancer { target_group_arn = aws_lb_target_group.api.arn
  container_name = "api"
  container_port = 5000 }
  depends_on = [aws_lb_listener.http, aws_iam_role_policy_attachment.task_execution]
  tags = local.common_tags
}
resource "aws_appautoscaling_target" "ecs" {
  max_capacity = 4
  min_capacity = 1
  resource_id = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.api.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace = "ecs"
}
resource "aws_appautoscaling_policy" "cpu" {
  name = "${local.name}-cpu-scaling"
  policy_type = "TargetTrackingScaling"
  resource_id = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace = aws_appautoscaling_target.ecs.service_namespace
  target_tracking_scaling_policy_configuration { target_value = 60
  predefined_metric_specification { predefined_metric_type = "ECSServiceAverageCPUUtilization" } }
}

# Resume worker: validates that the uploaded object exists. Add PDF extraction/AI only after testing.
data "archive_file" "resume_worker" { type = "zip"
  source_dir = "${path.module}/../lambda/resume_worker"
  output_path = "${path.module}/resume_worker.zip" }
resource "aws_iam_role" "lambda_resume" {
  name = "${local.name}-resume-worker"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }] })
  tags = local.common_tags
}
resource "aws_iam_role_policy_attachment" "lambda_logs" { role = aws_iam_role.lambda_resume.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" }
resource "aws_iam_role_policy" "lambda_sqs_s3" {
  name = "${local.name}-resume-worker-access"
  role = aws_iam_role.lambda_resume.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"], Resource = aws_sqs_queue.resume.arn },
    { Effect = "Allow", Action = ["s3:GetObject"], Resource = "${aws_s3_bucket.resumes.arn}/resumes/*" }
  ] })
}
resource "aws_lambda_function" "resume_worker" {
  function_name = "${local.name}-resume-worker"
  role = aws_iam_role.lambda_resume.arn
  runtime = "python3.12"
  handler = "handler.handler"
  filename = data.archive_file.resume_worker.output_path
  source_code_hash = data.archive_file.resume_worker.output_base64sha256
  timeout = 60
  memory_size = 256
  environment { variables = { S3_BUCKET = aws_s3_bucket.resumes.bucket } }
  tags = local.common_tags
}
resource "aws_lambda_event_source_mapping" "resume_queue" {
  event_source_arn = aws_sqs_queue.resume.arn
  function_name = aws_lambda_function.resume_worker.arn
  batch_size = 5
  function_response_types = ["ReportBatchItemFailures"]
  depends_on = [aws_iam_role_policy.lambda_sqs_s3, aws_iam_role_policy_attachment.lambda_logs]
}
resource "aws_cloudwatch_event_rule" "app_events" {
  name = "${local.name}-application-events"
  event_bus_name = aws_cloudwatch_event_bus.main.name
  event_pattern = jsonencode({ source = ["talentflow.application"], "detail-type" = ["JOB_CREATED", "CANDIDATE_CREATED", "APPLICATION_CREATED", "RESUME_UPLOADED"] })
  tags = local.common_tags
}
resource "aws_cloudwatch_event_target" "events_to_sns" {
  rule = aws_cloudwatch_event_rule.app_events.name
  event_bus_name = aws_cloudwatch_event_bus.main.name
  target_id = "notifications"
  arn = aws_sns_topic.notifications.arn
}
resource "aws_sns_topic_policy" "allow_events" {
  arn = aws_sns_topic.notifications.arn
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Sid = "AllowEventBridgePublish", Effect = "Allow", Principal = { Service = "events.amazonaws.com" }, Action = "sns:Publish", Resource = aws_sns_topic.notifications.arn }] })
}

# Static frontend hosting. Upload the repository's index.html, style.css, script.js and 1.png to this bucket.
resource "aws_s3_bucket" "frontend" { bucket_prefix = "${local.name}-frontend-"
  force_destroy = false
  tags = local.common_tags }
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}
resource "aws_cloudfront_origin_access_control" "frontend" {
  name = "${local.name}-frontend-oac"
  description = "Private S3 origin access"
  origin_access_control_origin_type = "s3"
  signing_behavior = "always"
  signing_protocol = "sigv4"
}
resource "aws_cloudfront_distribution" "frontend" {
  enabled = true
  default_root_object = "index.html"
  price_class = "PriceClass_100"
  origin { domain_name = aws_s3_bucket.frontend.bucket_regional_domain_name
  origin_id = "frontend-s3"
  origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id }
  default_cache_behavior {
    target_origin_id = "frontend-s3"
  viewer_protocol_policy = "redirect-to-https"
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
  cached_methods = ["GET", "HEAD"]
    forwarded_values { query_string = false
  cookies { forward = "none" } }
  }
  restrictions { geo_restriction { restriction_type = "none" } }
  viewer_certificate { cloudfront_default_certificate = true }
  tags = local.common_tags
}
resource "aws_s3_bucket_policy" "frontend_cloudfront" {
  bucket = aws_s3_bucket.frontend.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Sid = "AllowCloudFrontReadOnly", Effect = "Allow", Principal = { Service = "cloudfront.amazonaws.com" }, Action = "s3:GetObject", Resource = "${aws_s3_bucket.frontend.arn}/*", Condition = { StringEquals = { "AWS:SourceArn" = aws_cloudfront_distribution.frontend.arn } } }] })
}

resource "aws_autoscaling_group" "asg_az" {
  for_each = try({ for i in local.asg_config : i.name => i if i.availability_zones != null }, {})

  name               = each.value.name               # Details: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group#name
  availability_zones = each.value.availability_zones # Details: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group#availability_zones

  desired_capacity = each.value.desired_capacity # Details: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group#desired_capacity
  max_size         = each.value.max_size         # Details: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group#max_size
  min_size         = each.value.min_size         # Details: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group#min_size

  default_cooldown          = each.value.default_cooldown          # Details: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group#default_cooldown
  health_check_grace_period = each.value.health_check_grace_period # Details: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group#health_check_grace_period
  health_check_type         = each.value.health_check_type         # Details: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group#health_check_type
  load_balancers            = each.value.load_balancers            # Details: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group#load_balancers
  target_group_arns         = each.value.target_group_arns         # Details: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group#target_group_arns

  force_delete = each.value.force_delete # Details: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group#force_delete

  # Details: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group#launch_template
  launch_template {
    id      = aws_launch_template.asg[each.key].id
    version = "$Latest"
  }

  dynamic "tag" {
    for_each = try(flatten([
      for i, t in local.common_tags : {
        k = i
        v = t.value
      }
    ]), [])

    content {
      key                 = tag.value.k
      value               = tag.value.v
      propagate_at_launch = true
    }
  }
}

resource "aws_autoscaling_group" "asg_vpc" {
  for_each = try({ for i in local.asg_config : i.name => i if i.vpc_zone_identifier != null }, {})

  name = each.value.name # Details: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group#name

  desired_capacity = each.value.desired_capacity # Details: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group#desired_capacity
  max_size         = each.value.max_size         # Details: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group#max_size
  min_size         = each.value.min_size         # Details: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group#min_size

  default_cooldown          = each.value.default_cooldown          # Details: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group#default_cooldown
  health_check_grace_period = each.value.health_check_grace_period # Details: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group#health_check_grace_period
  health_check_type         = each.value.health_check_type         # Details: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group#health_check_type
  load_balancers            = each.value.load_balancers            # Details: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group#load_balancers
  vpc_zone_identifier       = each.value.vpc_zone_identifier       # Details: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group#vpc_zone_identifier
  target_group_arns         = each.value.target_group_arns         # Details: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group#target_group_arns

  force_delete = each.value.force_delete # Details: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group#force_delete

  # Details: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group#launch_template
  launch_template {
    id      = aws_launch_template.asg[each.key].id
    version = "$Latest"
  }

  dynamic "tag" {
    for_each = try(flatten([
      for i, t in local.common_tags : {
        k = i
        v = t.value
      }
    ]), [])

    content {
      key                 = tag.value.k
      value               = tag.value.v
      propagate_at_launch = true
    }
  }
}

resource "aws_launch_template" "asg" {
  for_each = try({ for p in local.launch_template_config : p.group_name => p }, {})

  name_prefix             = "${each.value.name}-config"
  image_id                = each.value.image_id
  instance_type           = each.value.instance_type
  disable_api_termination = each.value.disable_api_termination
  ebs_optimized           = each.value.ebs_optimized

  iam_instance_profile {
    name = aws_iam_instance_profile.asg[each.key].id
  }

  dynamic "block_device_mappings" {
    for_each = each.value.block_devices

    content {
      device_name  = block_device_mappings.value["name"]
      virtual_name = block_device_mappings.value["virtual_name"]

      ebs {
        volume_size = block_device_mappings.value["size"]
      }
    }
  }

  dynamic "capacity_reservation_specification" {
    for_each = each.value.capacity_reservation

    content {
      capacity_reservation_preference = capacity_reservation_specification.value.preference
    }
  }

  dynamic "cpu_options" {
    for_each = each.value.cpu_options

    content {
      core_count       = cpu_options.value.core_count
      threads_per_core = cpu_options.value.threads_per_core
    }
  }

  dynamic "credit_specification" {
    for_each = each.value.credit_specification

    content {
      cpu_credits = credit_specification.value.cpu_credits
    }
  }

  dynamic "elastic_gpu_specifications" {
    for_each = each.value.elastic_gpu_specifications

    content {
      type = elastic_gpu_specifications.value.type
    }
  }

  dynamic "elastic_inference_accelerator" {
    for_each = each.value.elastic_inference_accelerator

    content {
      type = elastic_inference_accelerator.value.type
    }
  }

  instance_initiated_shutdown_behavior = each.value.instance_initiated_shutdown_behavior

  dynamic "instance_market_options" {
    for_each = each.value.instance_market_options

    content {
      market_type = "spot"
      spot_options {
        block_duration_minutes         = instance_market_options.value.block_duration_minutes
        instance_interruption_behavior = instance_market_options.value.instance_interruption_behavior
        max_price                      = instance_market_options.value.max_price
        spot_instance_type             = instance_market_options.value.spot_instance_type
        valid_until                    = instance_market_options.value.valid_until
      }
    }
  }

  kernel_id = each.value.kernel_id

  key_name = each.value.ssh_key_name

  dynamic "license_specification" {
    for_each = each.value.license_specification

    content {
      license_configuration_arn = license_specification.value.arn
    }
  }

  dynamic "metadata_options" {
    for_each = each.value.metadata_options

    content {
      http_endpoint               = metadata_options.value.http_endpoint
      http_tokens                 = metadata_options.value.http_tokens
      http_put_response_hop_limit = metadata_options.value.http_put_response_hop_limit
      instance_metadata_tags      = metadata_options.value.instance_metadata_tags
    }
  }

  dynamic "monitoring" {
    for_each = each.value.monitoring

    content {
      enabled = monitoring.value.enabled
    }
  }

  dynamic "network_interfaces" {
    for_each = each.value.network_interfaces

    content {
      associate_public_ip_address = network_interfaces.value.associate_public_ip_address
    }
  }

  dynamic "placement" {
    for_each = each.value.placement

    content {
      availability_zone = placement.value.availability_zone
    }
  }

  ram_disk_id = each.value.ram_disk_id

  vpc_security_group_ids = each.value.vpc_security_group_ids

  dynamic "tag_specifications" {
    for_each = each.value.tag_specifications

    content {
      resource_type = tag_specifications.value.type
      tags          = tag_specifications.value.tags
    }
  }

  user_data = base64encode(file("${path.module}/${each.value.user_data}"))
}

resource "aws_autoscaling_schedule" "asg" {
  for_each = { for i in local.schedule_config : i.name => i }

  scheduled_action_name  = each.value.name
  min_size               = each.value.min_size
  max_size               = each.value.max_size
  desired_capacity       = each.value.desired_capacity
  start_time             = each.value.start_time
  end_time               = each.value.end_time
  autoscaling_group_name = each.value.is_vpc ? aws_autoscaling_group.asg_vpc[each.value.group_name].name : aws_autoscaling_group.asg_az[each.value.group_name].name
}

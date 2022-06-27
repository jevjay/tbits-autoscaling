locals {
  // Pipeline YAML config parser
  config = try(yamldecode(file(var.config))["config"], {})

  asg_config = try(flatten([
    for config in local.config : {
      # Required
      name         = config.name
      ssh_key_name = config.ssh_key_name
      kernel_id    = config.kernel_id
      ram_disk_id  = config.ram_disk_id
      # Optional
      vpc_security_group_ids    = try(config.vpc_security_group_ids, [])
      desired_capacity          = try(config.desired_capacity, 0)
      min_size                  = try(config.min_size, 0)
      max_size                  = try(config.max_size, 0)
      default_cooldown          = try(config.default_cooldown, 300)
      health_check_grace_period = try(config.health_check_grace_period, 300)
      health_check_type         = try(config.health_check_type, "EC2")
      force_delete              = try(config.force_delete, false)
      load_balancers            = try(config.load_balancers, [])
      availability_zones        = try(config.availability_zones, null)
      vpc_zone_identifier       = try(config.vpc_zone_identifier, null)
      target_group_arns         = try(config.target_group_arns, [])
    }
  ]), [])

  schedule_config = try(flatten([
    for config in local.config : [
      for rule in config.schedule : {
        group_name       = config.name
        is_vpc           = try(config.vpc_zone_identifier, null) != null ? true : false
        name             = rule.name
        min_size         = rule.min_size
        max_size         = rule.max_size
        desired_capacity = rule.desired_capacity
        start_time       = rule.start_time
        end_time         = rule.end_time
      }
    ]
  ]), [])

  scaling_config = try(flatten([
    for config in local.config : [
      for policy in config.scaling : {
        group_name         = config.name
        is_vpc             = try(config.vpc_zone_identifier, null) != null ? true : false
        name               = policy.name
        scaling_adjustment = policy.scaling_adjustment
        adjustment_type    = policy.adjustment_type
        cooldown           = policy.cooldown
        policy_type        = try(policy.type, "SimpleScaling")

        predictive_scaling_configuration = try(flatten([
          for cfg in policy.predictive_scaling_configuration : {
            metric_specification = {
              target_value = lookup(cfg.metric_specification, "target_value", null)

              customized_load_metric = try(flatten([
                for load_metric in lookup(cfg.metric_specification, "customized_load_metric", {}) : [
                  for data_queries in load_metric.metric_data_queries : {
                    id          = data_queries.id
                    expression  = data_queries.expression
                    return_data = data_queries.return_data
                    label       = data_queries.label
                    metric_stat = {}
                  }
                ]
              ]), {})

              customized_capacity_metric = try(flatten([
                for capacity_metric in lookup(cfg.metric_specification, "customized_capacity_metric", {}) : [
                  for data_queries in capacity_metric.metric_data_queries : {
                    id          = data_queries.id
                    expression  = data_queries.expression
                    return_data = data_queries.return_data
                    label       = data_queries.label
                    metric_stat = {}
                  }
                ]
              ]), {})

              customized_scaling_metric = try(flatten([
                for scaling_metric in lookup(cfg.metric_specification, "customized_scaling_metric", {}) : [
                  for data_queries in scaling_metric.metric_data_queries : {
                    id          = data_queries.id
                    expression  = data_queries.expression
                    return_data = data_queries.return_data
                    label       = data_queries.label
                    metric_stat = {}
                  }
                ]
              ]), {})
            }
          }
        ]), {})
      }
    ]
  ]), [])

  # IAM role (instance profile) configuration
  instance_profile_config = try(flatten([
    for config in local.config : {
      group_name  = config.name
      name        = lookup(config.instance_profile, "name", null)
      policy_json = lookup(config.instance_profile, "policy_json", "")
  }]), {})

  launch_template_config = try(flatten([
    for config in local.config : {
      group_name                           = config.name
      name                                 = lookup(config.launch_template, "name", config.name)
      image_id                             = lookup(config.launch_template, "image_id", null)
      instance_type                        = lookup(config.launch_template, "instance_type", null)
      disable_api_termination              = lookup(config.launch_template, "disable_api_termination", false)
      ebs_optimized                        = lookup(config.launch_template, "disable_api_termination", false)
      instance_initiated_shutdown_behavior = lookup(config.launch_template, "instance_initiated_shutdown_behavior", "stop")
      kernel_id                            = lookup(config.launch_template, "kernel_id", null)
      ssh_key_name                         = lookup(config.launch_template, "ssh_key_name", null)
      ram_disk_id                          = lookup(config.launch_template, "ram_disk_id", null)
      vpc_security_group_ids               = lookup(config.launch_template, "vpc_security_group_ids", [])
      user_data                            = lookup(config.launch_template, "user_data", "./user_data.sh")

      block_devices = try(flatten([
        for device in lookup(config.launch_template, "block_devices", []) : {
          name         = device.name
          virtual_name = device.virtual_name
          size         = device.size
        }
      ]), {})

      capacity_reservation = try(flatten([
        for res in lookup(config.launch_template, "capacity_reservation", {}) : {
          capacity_reservation_preference = res.capacity_reservation_preference
        }
      ]), {})

      cpu_options = try(flatten([
        for opt in lookup(config.launch_template, "cpu_options", {}) : {
          core_count       = opt.core_count
          threads_per_core = opt.threads_per_core
        }
      ]), {})

      credit_specification = try(flatten([
        for spec in lookup(config.launch_template, "credit_specification", {}) : {
          group_name = spec.group_name
          preference = spec.credit_specification
        }
      ]), {})

      elastic_gpu_specifications = try(flatten([
        for spec in lookup(config.launch_template, "elastic_gpu_specifications", {}) : {
          type = spec.type
        }
      ]), {})

      elastic_inference_accelerator = try(flatten([
        for accelerator in lookup(config.launch_template, "elastic_inference_accelerator", {}) : {
          type = accelerator.type
        }
      ]), {})

      license_specification = try(flatten([
        for spec in lookup(config.launch_template, "license_specification", {}) : {
          arn = spec.arn
        }
      ]), {})

      metadata_options = try(flatten([
        for meta in lookup(config.launch_template, "metadata", {}) : {
          http_endpoint               = meta.http_endpoint
          http_tokens                 = meta.http_tokens
          http_put_response_hop_limit = meta.http_put_response_hop_limit
          instance_metadata_tags      = meta.instance_metadata_tags
        }
      ]), {})

      monitoring = try(flatten([
        for cfg in lookup(config.launch_template, "monitoring", {}) : {
          enabled = cfg.enabled
        }
      ]), {})

      network_interfaces = try(flatten([
        for cfg in lookup(config.launch_template, "network_interfaces", {}) : {
          associate_public_ip_address = cfg.associate_public_ip_address
        }
      ]), {})

      placement = try(flatten([
        for cfg in lookup(config.launch_template, "placement", {}) : {
          availability_zone = cfg.availability_zone
        }
      ]), {})

      tag_specifications = try(flatten([
        for spec in lookup(config.launch_template, "tag_specifications", {}) : {
          resource_type = spec.resource_type
          tags          = spec.tags
        }
      ]), {})

      instance_market_options = try(flatten([
        for opt in lookup(config.launch_template, "instance_market_options", {}) : {
          block_duration_minutes         = opt.block_duration_minutes
          instance_interruption_behavior = opt.instance_interruption_behavior
          max_price                      = opt.max_price
          spot_instance_type             = opt.spot_instance_type
          valid_until                    = opt.valid_until
        }
      ]), {})
    }
  ]), {})

  common_tags = merge(var.shared_tags, { Terraformed = "true" })
}

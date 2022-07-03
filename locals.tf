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

  scaling_config = flatten([
    for config in local.config : [
      for policy in config.scaling : {
        group_name                = config.name
        is_vpc                    = try(config.vpc_zone_identifier, null) != null ? true : false
        name                      = policy.name
        scaling_adjustment        = try(policy.scaling_adjustment, null)
        adjustment_type           = policy.adjustment_type
        cooldown                  = try(policy.cooldown, null)
        policy_type               = try(policy.type, "SimpleScaling")
        estimated_instance_warmup = try(policy.estimated_instance_warmup, null)
        enabled                   = try(policy.enabled, true)
        min_adjustment_magnitude  = try(policy.min_adjustment_magnitude, null)
        metric_aggregation_type   = try(policy.metric_aggregation_type, null)

        step_adjustment = [
          for step in try(policy.step_adjustment, {}) : {
            scaling_adjustment          = step.scaling_adjustment
            metric_interval_lower_bound = step.metric_interval_lower_bound
            metric_interval_upper_bound = step.metric_interval_upper_bound
          }
        ]

        target_tracking_configuration = [
          for cfg in try(policy.target_tracking_configuration, {}) : {
            target_value     = cfg.target_value
            disable_scale_in = try(cfg.disable_scale_in, false)
            predefined_metric_specification = [{
              type           = lookup(cfg.predefined_metric_specification, "type", null)
              resource_label = lookup(cfg.predefined_metric_specification, "resource_label", null)
            }]
            customized_metric_specification = [{
              dimension = lookup(cfg.customized_metric_specification, "dimension", {})
              name      = lookup(cfg.customized_metric_specification, "name")
              namespace = lookup(cfg.customized_metric_specification, "namespace", null)
              statistic = lookup(cfg.customized_metric_specification, "statistic", null)
              unit      = lookup(cfg.customized_metric_specification, "unit", null)
            }]
          }
        ]

        predictive_scaling_configuration = [
          for cfg in try(policy.predictive_scaling_configuration, {}) : {
            max_capacity_breach_behavior = try(cfg.max_capacity_breach_behavior, "HonorMaxCapacity")
            max_capacity_buffer          = try(cfg.max_capacity_buffer, null)
            mode                         = try(cfg.mode, "ForecastOnly")
            scheduling_buffer_time       = try(cfg.scheduling_buffer_time, 0)

            metric_specification = {
              target_value = lookup(cfg.metric_specification, "target_value", null)

              predefined_load_metric = lookup(cfg.metric_specification, "predefined_load_metric", {})

              predefined_metric_pair = lookup(cfg.metric_specification, "predefined_metric_pair", {})

              predefined_scaling_metric = lookup(cfg.metric_specification, "predefined_scaling_metric", {})

              customized_load_metric = lookup(cfg.metric_specification, "customized_load_metric", {}) != {} ? {
                metric_data_queries = [
                  for query in lookup(cfg.metric_specification, "customized_load_metric", {}) : {
                    id          = try(query.id, null)
                    expression  = try(query.expression, null)
                    return_data = try(query.return_data, null)
                    label       = try(query.label, null)
                    metric_stat = try([{
                      name      = lookup(query.metric_stat.metric, "name", null)
                      namespace = lookup(query.metric_stat.metric, "namespace", null)
                      stat      = lookup(query.metric_stat.metric, "stat", null)
                      dimensions = {
                        dimension = lookup(query.metric_stat.metric, "dimensions", {})
                      }
                    }], [])
                  }
                ]
              } : {}

              customized_capacity_metric = lookup(cfg.metric_specification, "customized_capacity_metric", {}) != {} ? {
                metric_data_queries = [
                  for query in lookup(cfg.metric_specification, "customized_capacity_metric", {}) : {
                    id          = try(query.id, null)
                    expression  = try(query.expression, null)
                    return_data = try(query.return_data, null)
                    label       = try(query.label, null)
                    metric_stat = try([{
                      name      = lookup(query.metric_stat.metric, "name", null)
                      namespace = lookup(query.metric_stat.metric, "namespace", null)
                      stat      = lookup(query.metric_stat.metric, "stat", null)
                      dimensions = {
                        dimension = lookup(query.metric_stat.metric, "dimensions", {})
                      }
                    }], [])
                  }
                ]
              } : {}

              customized_scaling_metric = lookup(cfg.metric_specification, "customized_scaling_metric", {}) != {} ? {
                metric_data_queries = [
                  for query in lookup(cfg.metric_specification, "customized_scaling_metric", {}) : {
                    id          = try(query.id, null)
                    expression  = try(query.expression, null)
                    return_data = try(query.return_data, null)
                    label       = try(query.label, null)
                    metric_stat = try([{
                      name      = lookup(query.metric_stat.metric, "name", null)
                      namespace = lookup(query.metric_stat.metric, "namespace", null)
                      stat      = lookup(query.metric_stat.metric, "stat", null)
                      dimensions = {
                        dimension = lookup(query.metric_stat.metric, "dimensions", {})
                      }
                    }], [])
                  }
                ]
              } : {}
            }
          }
        ]
      }
    ]
  ])

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

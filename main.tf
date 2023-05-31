# Terraform 0.13+ requires providers to be declared in a "required_providers" block
terraform {
  required_providers {
    fastly = {
      source  = "fastly/fastly"
      version = ">= 3.0.4"
    }
  }
}

# Configure the Fastly Provider
provider "fastly" {
  api_key = var.FASTLY_API_KEY
}

# Create a Service
resource "fastly_service_vcl" "edge-rate-limiting-terraform-service" {
  name = "edge-rate-limiting-terraform"

  domain {
    name    = var.USER_DOMAIN_NAME
    comment = "demo for configuring edge rate limiting with terraform"
  }
    
  backend {
    address = var.USER_DEFAULT_BACKEND_HOSTNAME
    name = "fastly_origin"
    port    = 443
    use_ssl = true
    ssl_cert_hostname = var.USER_DEFAULT_BACKEND_HOSTNAME
    ssl_sni_hostname = var.USER_DEFAULT_BACKEND_HOSTNAME
    override_host = var.USER_DEFAULT_BACKEND_HOSTNAME
  }
   
    # snippet {
    #   name = "Default Edge Rate Limiting"
    #   content = file("${path.module}/snippets/default_edge_rate_limiting.vcl")
    #   type = "init"
    #   priority = 100
    # }

    #### Rate limit with lower volume traffic
  snippet {
    name = "Low Volume Login Edge Rate Limiting"
    content = file("${path.module}/snippets/edge_rate_limiting_low_volume.vcl")
    type = "init"
    priority = 90
  }

    #### Debug Rate limit with lower volume traffic - ONLY USE FOR DEBUGGING SINCE THIS SENDS RATE COUNT INFORMATION BACK TO THE CLIENT
  snippet {
    name = "Debug Low Volume Login Edge Rate Limit"
    content = file("${path.module}/snippets/debug_low_volume_edge_rate_limit.vcl")
    type = "deliver"
    priority = 100
  }

    # snippet {
    #   name = "Edge Rate Limiting with URL as key"
    #   content = file("${path.module}/snippets/edge_rate_limiting_url_key.vcl")
    #   type = "init"
    #   priority = 105
    # }

    ##### Rate limit by org name when it is a hosting provider - Red Sauron
    # snippet {
    #   name = "Rate Limit by ASN Name"
    #   content = file("${path.module}/snippets/edge_rate_limiting_asname_key.vcl")
    #   type = "init"
    #   priority = 106
    # }

  ##### Rate limit by request header "user-id" - Orange frodo
  snippet {
    name = "Edge Rate Limit by user-id request header"
    content = file("${path.module}/snippets/edge_rate_limiting_request_header.vcl")
    type = "init"
    priority = 110
  }

  ##### origin_waf_response
  snippet {
    name = "Origin Response Penalty Box"
    content = file("${path.module}/snippets/origin_response_penalty_box.vcl")
    type = "init"
    priority = 130
  }
    

    ##### Rate limit by URL and group specific URLs together - Advanced case
    # snippet {
    #   name = "Edge Rate Limiting with URL as key - Advanced"
    #   content = file("${path.module}/snippets/edge_rate_limiting_url_key_advanced.vcl")
    #   type = "init"
    #   priority = 140
    # }

    ##### It is necessecary to disable caching for ERL to increment the counter for origin/backend requests
  snippet {
    name = "Disable caching"
    content = file("${path.module}/snippets/disable_caching.vcl")
    type = "recv"
    priority = 100
  }

  dictionary {
    name       = "login_paths"
  }

  dictionary {
    name       = "login_edge_rate_limit_config"
  }

    force_destroy = true
}

resource "fastly_service_dictionary_items" "login_paths_dictionary_items" {
  for_each = {
  for d in fastly_service_vcl.edge-rate-limiting-terraform-service.dictionary : d.name => d if d.name == "login_paths"
  }
  service_id = fastly_service_vcl.edge-rate-limiting-terraform-service.id
  dictionary_id = each.value.dictionary_id

  items = {
    "/login": 1,
    "/auth": 2,
    "/gateway": 3,
    "/identity": 4,
  }

  manage_items = false
}

resource "fastly_service_dictionary_items" "login_edge_rate_limit_config_dictionary_items" {
  for_each = {
  for d in fastly_service_vcl.edge-rate-limiting-terraform-service.dictionary : d.name => d if d.name == "login_edge_rate_limit_config"
  }
  service_id = fastly_service_vcl.edge-rate-limiting-terraform-service.id
  dictionary_id = each.value.dictionary_id

  # rate_limit_rpm_value may not be less than 10
  items = {
    "rate_limit_rpm_value": "5",
    "blocking": "true",
    "rate_limit_delta_value": "1",
  }
  manage_items = true
}

output "live_laugh_love_edge_rate_limiting" {
  # How to test example
  value = <<tfmultiline

    #### Click the URL to go to the service ####
    https://cfg.fastly.com/${fastly_service_vcl.edge-rate-limiting-terraform-service.id}

    # The following commands are useful for testing.
    
    ## Rate Limit based on request header user-id
    siege "https://${var.USER_DOMAIN_NAME}/foo/v1/login" --header "user-id: 1" -t 5s

    ## Rate Limit based on URL
    siege "https://${var.USER_DOMAIN_NAME}/foo/v1/menu/abc" -t 5s

    ## Add IP to Rate Limit Penalty box based on origin data
    echo "GET https://${var.USER_DOMAIN_NAME}/some/path/123?x-obj-status=206" | vegeta attack -header "vegeta-test:ratelimittest1" -duration=30s  | vegeta report -type=text

    # Run the following curl and vegeta commands in a seperate adjacent windows with domain inspector to see the blocks in the Fastly UI.

    watch -n0.5 'curl -isD - -o /dev/null https://${var.USER_DOMAIN_NAME}/status?x-obj-status=200 -H "fastly-debug:1" -H "user-id:xyz-123"'
    
    echo "GET https://${var.USER_DOMAIN_NAME}/status?x-obj-status=200" | vegeta attack -header "user-id:abc-123" -duration=120s  | vegeta report -type=text
    
    # Navigate to the Domain Inspector UI
    https://manage.fastly.com/stats/real-time/services/${fastly_service_vcl.edge-rate-limiting-terraform-service.id}/datacenters/all/domains/

  tfmultiline
}

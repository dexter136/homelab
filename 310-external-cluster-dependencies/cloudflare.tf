data "cloudflare_zone" "dex136" {
  name = "dex136.xyz"
}

data "cloudflare_api_token_permission_groups" "all" {}

data "http" "public_ipv4" {
  url = "https://ipv4.icanhazip.com"
}

locals {
  public_ips = [
    "${chomp(data.http.public_ipv4.body)}/32",
  ]
}

resource "cloudflare_filter" "countries" {
  zone_id     = data.cloudflare_zone.dex136.id
  description = "Expression to block all countries except US and CA"
  expression  = "(ip.geoip.country ne \"US\" and ip.geoip.country ne \"CA\")"
}

resource "cloudflare_firewall_rule" "countries" {
  zone_id     = data.cloudflare_zone.dex136.id
  description = "Firewall rule to block all countries except US and CA"
  filter_id   = cloudflare_filter.countries.id
  action      = "block"
}

resource "cloudflare_filter" "bots" {
  zone_id     = data.cloudflare_zone.dex136.id
  description = "Expression to block bots determined by CF"
  expression  = "(cf.client.bot)"
}

resource "cloudflare_firewall_rule" "bots" {
  zone_id     = data.cloudflare_zone.dex136.id
  description = "Firewall rule to block bots determined by CF"
  filter_id   = cloudflare_filter.bots.id
  action      = "block"
}

resource "cloudflare_filter" "threats" {
  zone_id     = data.cloudflare_zone.dex136.id
  description = "Expression to block medium threats"
  expression  = "(cf.threat_score gt 14)"
}

resource "cloudflare_firewall_rule" "threats" {
  zone_id     = data.cloudflare_zone.dex136.id
  description = "Firewall rule to block medium threats"
  filter_id   = cloudflare_filter.threats.id
  action      = "block"
}

resource "cloudflare_api_token" "system_api_token" {
  name = "homelab_system_namespace"

  policy {
    permission_groups = [
      data.cloudflare_api_token_permission_groups.all.permissions["Zone Read"],
      data.cloudflare_api_token_permission_groups.all.permissions["DNS Write"]
    ]
    resources = {
      "com.cloudflare.api.account.zone.*" = "*"
    }
  }

  condition {
    request_ip {
      in = local.public_ips
    }
  }
}

resource "kubernetes_secret" "cf_api_token" {
  metadata {
    name      = "cloudflare-api-token"
    namespace = "system"
  }

  data = {
    "api-token" = cloudflare_api_token.system_api_token.value
  }
}

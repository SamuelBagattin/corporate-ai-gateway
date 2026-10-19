# Delegated sub-zone: external-dns only gets write access to this zone,
# never to the parent.

data "aws_route53_zone" "parent" {
  name         = var.parent_domain
  private_zone = false
}

resource "aws_route53_zone" "main" {
  name    = local.domain
  comment = "EKS cluster ${var.cluster_name}. Managed by Terraform."
}

resource "aws_route53_record" "delegation" {
  zone_id = data.aws_route53_zone.parent.zone_id
  name    = local.domain
  type    = "NS"
  ttl     = 300
  records = aws_route53_zone.main.name_servers
}

resource "aws_acm_certificate" "main" {
  domain_name               = local.domain
  subject_alternative_names = ["*.${local.domain}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id         = aws_route53_zone.main.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for r in aws_route53_record.acm_validation : r.fqdn]

  depends_on = [aws_route53_record.delegation]
}

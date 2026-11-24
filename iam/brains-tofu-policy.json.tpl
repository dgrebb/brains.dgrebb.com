{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Identity",
      "Effect": "Allow",
      "Action": "sts:GetCallerIdentity",
      "Resource": "*"
    },
    {
      "Sid": "Route53ZoneDiscovery",
      "Effect": "Allow",
      "Action": [
        "route53:ListHostedZones",
        "route53:ListHostedZonesByName"
      ],
      "Resource": "*"
    },
    {
      "Sid": "Route53ZoneRecords",
      "Effect": "Allow",
      "Action": [
        "route53:GetHostedZone",
        "route53:ListResourceRecordSets",
        "route53:ListTagsForResource",
        "route53:ChangeResourceRecordSets"
      ],
      "Resource": "arn:aws:route53:::hostedzone/__ZONE_ID__"
    },
    {
      "Sid": "Route53ChangePolling",
      "Effect": "Allow",
      "Action": "route53:GetChange",
      "Resource": "arn:aws:route53:::change/*"
    },
    {
      "Sid": "AcmReadForLookupFallback",
      "Effect": "Allow",
      "Action": [
        "acm:ListCertificates",
        "acm:DescribeCertificate"
      ],
      "Resource": "*"
    },
    {
      "Sid": "CloudFrontReadAndCreate",
      "Effect": "Allow",
      "Action": [
        "cloudfront:ListDistributions",
        "cloudfront:CreateDistribution",
        "cloudfront:ListCachePolicies",
        "cloudfront:GetCachePolicy",
        "cloudfront:GetCachePolicyConfig"
      ],
      "Resource": "*"
    },
    {
      "Sid": "CloudFrontManageThisDistribution",
      "Effect": "Allow",
      "Action": [
        "cloudfront:GetDistribution",
        "cloudfront:GetDistributionConfig",
        "cloudfront:UpdateDistribution",
        "cloudfront:DeleteDistribution",
        "cloudfront:TagResource",
        "cloudfront:UntagResource",
        "cloudfront:ListTagsForResource",
        "cloudfront:CreateInvalidation"
      ],
      "Resource": "arn:aws:cloudfront::__ACCOUNT_ID__:distribution/__DISTRIBUTION_ID__"
    }
  ]
}

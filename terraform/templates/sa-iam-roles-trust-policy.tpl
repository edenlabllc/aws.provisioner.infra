{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Principal": {
                "Federated": "${oidc_issuer_arn}"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "oidc.eks.${region}.amazonaws.com/id/${oidc_issuer_id}:sub": "system:serviceaccount:${service_account_name}"
                }
            }
        }
    ]
}

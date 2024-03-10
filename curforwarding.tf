locals {
  remote_bucket_arn = var.enable_cur_collection ? var.cur_forwarding_bucket_arn : "arn:aws:s3:::example-bucket"
}

data "aws_iam_policy_document" "cur_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cur_forwarding" {
  count = var.enable_cur_collection ? 1 : 0

  name_prefix        = "cur_forwarding"
  assume_role_policy = data.aws_iam_policy_document.cur_assume.json
}

data "aws_iam_policy_document" "cur_forwarding" {
  statement {
    effect = "Allow"

    actions = [
      "s3:GetReplicationConfiguration",
      "s3:ListBucket",
    ]

    resources = [local.local_bucket_arn]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging",
    ]

    resources = ["${local.local_bucket_arn}/*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags",
    ]

    resources = ["${local.remote_bucket_arn}/*"]
  }
}

resource "aws_iam_policy" "cur_forwarding" {
  count = var.enable_cur_collection ? 1 : 0

  name_prefix = "cur-forwarding"
  policy      = data.aws_iam_policy_document.cur_forwarding.json
}

resource "aws_iam_role_policy_attachment" "cur_forwarding" {
  count = var.enable_cur_collection ? 1 : 0

  role       = aws_iam_role.cur_forwarding[0].name
  policy_arn = aws_iam_policy.cur_forwarding[0].arn
}

resource "aws_s3_bucket_replication_configuration" "replication" {
  count = var.enable_cur_collection ? 1 : 0

  bucket = local.local_bucket_arn
  role   = aws_iam_role.cur_forwarding[0].arn

  rule {
    id     = "cur"
    status = "Enabled"

    filter {
      prefix = "cur/${local.account_id}/"
    }

    destination {
      bucket        = local.remote_bucket_arn
      storage_class = "STANDARD"
    }
  }

  depends_on = [aws_s3_bucket_versioning.local_cur]

}

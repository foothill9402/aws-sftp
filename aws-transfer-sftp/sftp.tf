resource "aws_iam_role" "sftp_role" {
  name = "tf-transfer-server-iam-role-${local.workspace_env}"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
        "Effect": "Allow",
        "Principal": {
            "Service": "transfer.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
        }
    ]
}
EOF
}

#Set SFTP user permissions.
resource "aws_iam_role_policy" "sftp_policy" {
  name = "tf-transfer-server-iam-policy-${local.workspace_env}"
  role = aws_iam_role.sftp_role.id

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
        "Sid": "AllowFullAccesstoCloudWatchLogs",
        "Effect": "Allow",
        "Action": [
            "logs:*"
        ],
        "Resource": "*"
        },
        {
			    "Effect": "Allow",
          "Action": [
            "s3:ListBucket",
            "s3:GetBucketLocation"
          ],
         "Resource": [
            "arn:aws:s3:::${local.sftp_bucket_name}"
          ]
        },
        {
          "Effect": "Allow",
          "Action": [
            "s3:PutObject",
            "s3:GetObject",
            "s3:DeleteObject",
            "s3:DeleteObjectVersion",
            "s3:GetObjectVersion",
            "s3:GetObjectACL",
            "s3:PutObjectACL"
          ],
          "Resource": [
            "arn:aws:s3:::${local.sftp_bucket_name}/${local.sftp_user}/*"
        ]
      }
    ]
}
POLICY
}

resource "aws_transfer_server" "sftp_server" {
  identity_provider_type = "SERVICE_MANAGED"
  logging_role           = aws_iam_role.sftp_role.arn

  tags = {
    Name        = "tf-acc-transfer-server-${local.workspace_env}"
    environment = local.environment
    Owner       = var.owner_name
  }
}

#create a folder for the user in S3 bucket which was previourly created. ( not part of this code )
resource "aws_s3_bucket_object" "s3_folder" {
  depends_on = [aws_s3_bucket.b]
  bucket     = local.sftp_bucket_name
  #bucket       = "sftp-bucket-ny2"
  key          = "${local.sftp_user}/"
  content_type = "application/x-directory"
  //  (Optional) Specifies the AWS KMS Key ARN to use for object encryption. This value is a fully qualified ARN of the KMS Key. 
  #kms_key_id = "${var.kms_key_arn}"
}

#create sftp user 
resource "aws_transfer_user" "ftp_user" {
  depends_on     = [aws_s3_bucket.b]
  server_id      = aws_transfer_server.sftp_server.id
  user_name      = local.sftp_user
  role           = aws_iam_role.sftp_role.arn
  home_directory = "/${local.sftp_bucket_name}/${local.sftp_user}"
}

#SSH key for user to manage sftp account
#Generate SSH key using PuttyGen
resource "aws_transfer_ssh_key" "ssh_key" {
  server_id = aws_transfer_server.sftp_server.id
  user_name = aws_transfer_user.ftp_user.user_name
  body      = "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAnWcF3YN40zjN4JnciHY3INunjbMnPdlUyu172UU6iN7NsbFWCHW2hvg4MKSizHOHTik4hz+xvWiJxw4wqt603LYKWEqXsGf3hGzYmQz0o3TQbjG0RgL8ttlfPsQUxYlRFqT064JPt0ulO5aPXU8azZBKctFi6PQehJuWvW28p86OhZ6cc+LbnvS2pwJ214nNUjI0U/IPQbk47I4JYbmAxzPVUIDodilEEwzUSavMTE/3gQeEpFasWIQta2cjMFnEKUGQ4gukTkbAcsKZqLeDpUwfD23/dT88osOOfKuEH81GaW/Q4oyLJe4fRIakdM8awCa6RbFU4T0k30ejdmvZOw== rsa-key-20210123"
}
               
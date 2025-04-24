terraform {
  required_version = ">=1.6.2"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">=6.12.0"
    }
    # google-beta = {
    #   source  = "hashicorp/google-beta"
    #   version = ">=6.12.0"
    # }
    random = {
      source  = "hashicorp/random"
      version = ">=3.1.0"
    }
  }
}

locals {
  key_ring_name              = "${var.name}-${random_string.key_suffix.result}"
  key_name                   = "${var.name}-${random_string.key_suffix.result}"
  rotation_period            = "31536000s" # 365 days
  destroy_scheduled_duration = "2592000s"  # 30 days
  purpose                    = "ENCRYPT_DECRYPT"
  algorithm                  = "GOOGLE_SYMMETRIC_ENCRYPTION"
  protection_level           = "HSM"

  identity_services = setsubtract(var.services, ["storage.googleapis.com", "bigquery.googleapis.com", "compute.googleapis.com"])

  identity_accounts = concat(
    [for identity in resource.google_project_service_identity.identity : "serviceAccount:${identity.email}"],
    contains(var.services, "storage.googleapis.com") ? ["serviceAccount:${data.google_storage_project_service_account.account[0].email_address}"] : [],
    contains(var.services, "bigquery.googleapis.com") ? ["serviceAccount:${data.google_bigquery_default_service_account.account[0].email}"] : [],
    ["serviceAccount:service-${data.google_project.project.number}@compute-system.iam.gserviceaccount.com"]
  )
}

data "google_project" "project" {
  project_id = var.project
}

data "google_storage_project_service_account" "account" {
  count   = contains(var.services, "storage.googleapis.com") ? 1 : 0
  project = var.project
}

data "google_bigquery_default_service_account" "account" {
  count   = contains(var.services, "bigquery.googleapis.com") ? 1 : 0
  project = var.project
}

resource "random_string" "key_suffix" {
  length  = 4
  upper   = false
  special = false
}

resource "google_kms_key_ring" "key_ring" {
  name     = local.key_ring_name
  project  = var.project
  location = var.location
}

resource "google_kms_crypto_key" "this" {
  name                       = local.key_name
  key_ring                   = google_kms_key_ring.key_ring.id
  rotation_period            = local.rotation_period
  destroy_scheduled_duration = local.destroy_scheduled_duration
  purpose                    = local.purpose
  labels                     = var.labels

  version_template {
    algorithm        = local.algorithm
    protection_level = local.protection_level
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "google_kms_crypto_key_iam_binding" "encrypters" {
  crypto_key_id = google_kms_crypto_key.this.id
  role          = "roles/cloudkms.cryptoKeyEncrypter"
  members       = concat(local.identity_accounts, var.encrypters)
}

resource "google_kms_crypto_key_iam_binding" "decrypters" {
  crypto_key_id = google_kms_crypto_key.this.id
  role          = "roles/cloudkms.cryptoKeyDecrypter"
  members       = concat(local.identity_accounts, var.decrypters)
}

resource "google_project_service_identity" "identity" {
  provider = google-beta
  for_each = local.identity_services

  project = var.project
  service = each.value
}

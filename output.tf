output "key_id" {
  value = google_kms_crypto_key.this.id
}

output "key_ring_id" {
  value = google_kms_key_ring.key_ring.id
}
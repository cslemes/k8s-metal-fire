# Create a new SSH key
resource "equinix_metal_ssh_key" "key1" {
  name       = "terraform-1"
  public_key = file("~/.ssh/metal_ed25519.pub")
}

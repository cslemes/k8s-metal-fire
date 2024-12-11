terraform output -json | jq -r '
  .master_ips.value as $masters |
  .worker_ips.value as $workers |
  {
    all: {
      children: {
        k8s_master: {
          hosts: (
            $masters | to_entries | map({
              (.key): {
                ansible_host: .value.public_ip,
                ansible_user: "root"
              }
            }) | add
          )
        },
        k8s_workers: {
          hosts: (
            $workers | to_entries | map({
              (.key): {
                ansible_host: .value.public_ip,
                ansible_user: "root"
              }
            }) | add
          )
        }
      }
    }
  }
' | yq -P > ../ansible/hosts.yaml
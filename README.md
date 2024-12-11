- Cilium
- ArgoCD
- Terraform
- Ansible
- Equinix Metal
- Kata Container
- Firecraker
- Helm

**Ambiente Local**
Ferramentas instaladas
- **Metal Cli** (Ferramenta de linha de comando da Equinix Metal)
```
go install github.com/equinix/metal-cli/cmd/metal@latest
```
- **Ansible** no **Linux** com pipx ou uv:
```bash
pipx install ansible-core

uvx ansible
```
 - **Ansible** no **Windows** com Docker:
 - Crie os alias no seu $PROFILE 
```powershell
function runansible { 
  docker run -ti --rm `
    -v "$HOME\.ssh:/root/.ssh" `
    -v "$HOME\.aws:/root/.aws" `
    -v "${PWD}:/apps" `
    -w /apps `
    alpine/ansible ansible @args
}  
New-Alias -Name ansible -Value runansible

function playbook {
  docker run -ti --rm `
    -v "$HOME\.ssh:/root/.ssh" `
    -v "$HOME\.aws:/root/.aws" `
    -v "${PWD}:/apps" `
    -w /apps alpine/ansible `
   bash -c `
   "chmod -R 700 /root/.ssh && ansible-playbook $($args -join ' ')"
}
New-Alias -Name ansible-playbook -Value playbook
```

- [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) siga a instalação para sua plataforma

## Parte 1: Criando servidores

Nessa guia eu vou usar a Equinix Metal para o ambiente de servidores, você também pode usar seu provedor de Bare metal preferido, ou ambiente de virtualização local se seu ambiente suportar virtualização aninhada (**Nested VT-x/AMD-V**).
os requisitos são mínimo 2 servidores com 2CPU e 4GB de Ram .

### Criando ambiente na Equinix Metal

**1. Crie uma conta na  [Equinix Metal](https://console.equinix.com/) , ou caso já tenha faça login.**
- No momento eles estão oferendo um crédito de $250,00 para testar a plataforma, o suficiente para seguir esse tutorial. O uso é cobrado por hora em instancias on demand, com cobrança mínima de 1 hora (Não adianta desligar depois de 1 minuto, vai cobrar 1 hora).
**2. Crie uma chave de API para acessar a Equinix.**
- No console da equinix, selecione o projeto em qual você vai criar suas maquinas, vá em project settings, e em api keys, adicione uma chave com permissão readwrite. 

![Api Equinix](https://i.ibb.co/qCrnp1B/CriarApi.png)


### Criando scripts Terraform para a implantação das máquinas

Siga as instruções abaixo para criar os arquivos e configurar a infraestrutura.

**1. Estrutura de Arquivos**

📂k8s-metal-fire/
	📂 terraform/
	    📄main.tf
	    📄output.tf
	    📄providers.tf
	    📄 terraform.tfvars
	    📄 variables.tf
	📂 ansible/    
	 ...

Crie a estrutura de pastas e arquivos. Use os comandos abaixo:

```bash
mkdir -p k8s-metal-fire/terraform
mkdir -p k8s-metal-fire/ansible/{build,inventory,scripts/devmapper}

touch k8s-metal-fire/terraform/{main.tf,output.tf,providers.tf,terraform.tfvars,variables.tf}
touch k8s-metal-fire/ansible/{build/firecracker,inventory/hosts.yml,scripts/devmapper/{create.sh,reload.sh}}
touch k8s-metal-fire/{cluster_bootstrap.yml,k8s_environment.yml,k8s_firecracker.yml,main.yml}
```

---

**2. Crie o arquivo main.tf**

Esse arquivo define os recursos que serão provisionados no **Equinix Metal**.

**Conteúdo:**

```hcl
resource "equinix_metal_device" "k8s_master" {
  count            = var.k8s_master.num_instances
  hostname         = "k8s-master-${count.index + 1}"
  plan             = var.k8s_master.plan
  metro            = var.em_region
  operating_system = var.k8s_master.operating_system
  billing_cycle    = var.billing_cycle
  project_id       = var.em_project_id

  tags = ["kubernetes", "master"]
}

resource "equinix_metal_device" "k8s_worker" {
  count            = var.k8s_nodes.num_instances
  hostname         = "k8s-worker-${count.index + 1}"
  plan             = var.k8s_nodes.plan
  metro            = var.em_region
  operating_system = var.k8s_nodes.operating_system
  billing_cycle    = var.billing_cycle
  project_id       = var.em_project_id

  tags = ["kubernetes", "worker"]
}
```

**O que faz:**

- Define dois tipos de máquinas:
    - **Masters**: Controlam o cluster Kubernetes.
    - **Workers**: Executam os workloads (cargas de trabalho).

---

***3. Crie o arquivo `output.tf`**

Esse arquivo define as saídas dos recursos provisionados.

**Conteúdo:**

```hcl
output "master_ips" {
  value = {
    for device in equinix_metal_device.k8s_master :
    device.hostname => {
      "public_ip"  = device.access_public_ipv4
      "private_ip" = device.access_private_ipv4
    }
  }
  description = "IP addresses of master nodes"
}

output "worker_ips" {
  value = {
    for device in equinix_metal_device.k8s_worker :
    device.hostname => {
      "public_ip"  = device.access_public_ipv4
      "private_ip" = device.access_private_ipv4
    }
  }
  description = "IP addresses of worker nodes"
}
```

**O que faz:**

- Mostra os **IPs públicos** e **privados** dos masters e workers após a execução do Terraform.

---

**4. Crie o arquivo `providers.tf`**

Esse arquivo configura o provedor do **Terraform**.
### Conteúdo:

```hcl
terraform {
  required_providers {
    equinix = {
      source  = "equinix/equinix"
      version = "2.11.0"
    }
  }
  # backend "gcs" {
  #   bucket = "cslemes-terraform"
  #}
}

provider "equinix" {
  auth_token = var.em_api_token
}
```

### O que faz:

- Configura o provedor **Equinix Metal** para gerenciar os recursos.
- Inclui um exemplo comentado de backend remoto para armazenar o estado do Terraform.

---

**5. Crie o arquivo `terraform.tfvars`**

Esse arquivo define os valores das variáveis.

### Conteúdo:

```hcl
em_api_token  = "xxxxxxxxxxxxxxxxxxxxxxxxx"
em_project_id = "xxxxxxxxxxxxxxxxxxxxxxxxxx"
em_region     = "da"

billing_cycle = "hourly"

k8s_master = {
  plan             = "c3.small.x86"
  ipxe_script_url  = ""
  operating_system = "ubuntu_24_04"
  num_instances    = 3
  tags             = ["k8s_master"]
}

k8s_nodes = {
  plan             = "c3.small.x86"
  ipxe_script_url  = ""
  operating_system = "ubuntu_24_04"
  num_instances    = 2
  tags             = ["k8s-nodes"]
}
```

**O que faz:**

- Define as credenciais (API token e ID do projeto).
- Configura os planos e características das máquinas para os masters e workers.

---

**6. Crie o arquivo `variables.tf`**

Esse arquivo declara as variáveis usadas no projeto.

**Conteúdo:**

```hcl
variable "em_api_token" {
  description = "Equinix Metal API Key"
  type        = string
}

variable "em_project_id" {
  description = "Equinix Metal Project ID"
  type        = string
}

variable "em_region" {
  description = "Equinix Metal region to use"
  type        = string
}

variable "billing_cycle" {
  description = "value of billing cycle"
  type        = string
}

variable "k8s_master" {
  description = "k8s master"
  type = object({
    plan             = string
    ipxe_script_url  = optional(string)
    operating_system = string
    num_instances    = number
    tags             = optional(list(string), [])
  })
}

variable "k8s_nodes" {
  description = "k8s nodes"
  type = object({
    plan             = string
    ipxe_script_url  = optional(string)
    operating_system = string
    num_instances    = number
    tags             = optional(list(string), [])
  })
}
```

**O que faz:**

- Declara as variáveis obrigatórias, como token, projeto, região, e configurações dos nós.

---

Com esses arquivos criados, você pode iniciar a implantação executando os seguintes comandos no diretório `terraform`:

```bash
terraform init      # Inicializa o projeto
terraform plan      # Exibe o plano de execução
terraform apply     # Aplica as configurações e provisiona os recursos
```

### Criando manifestos Ansible para configuração do cluster Kubernetes

Você pode criar os arquivos necessários para o Ansible em uma estrutura organizada. Aqui está um guia passo a passo para criar e organizar os arquivos mencionados:

---
**1. Estrutura de diretórios**

Crie os seguintes diretórios e arquivos no seu projeto:

📂 ansible/
    📂 group_vars/ 
    📂 host_vars/
    📂 roles/
        📂 k8s_environment/
	        📂 scripts/
		        📂 devmapper/
			        📄 create.sh
			        📄 reload.sh
				📄 devmapper_reload.service
            📂 tasks/
                📄 main.yml
        📂 k8s_bootstrap/
	        📂 build/
		        📄firecraker
            📂 tasks/
                📄 main.yml
        📂 k8s_firecracker/
            📂 tasks/
                📄 main.yml
        📂 apply_kata/
            📂 tasks/
                📄 main.yml
    📄 hosts.yml
    📄 playbook.yml

**2. Arquivo `hosts.yml`**

Define os grupos de hosts (master e workers), vamos cria-lo a partir do output do terraform aqui é um exemplo:

```yaml
all:
  children:
    k8s_master:
      hosts:
        node1:
          ansible_host: 147.75.45.67
          ansible_user: root
    workers:
      hosts:
        node:
          ansible_host: 147.28.197.223
          ansible_user: root

```

---

**3. Arquivo `playbook.yml`**

O ponto de entrada principal do Ansible:

```yaml
- name: Setup Kubernetes cluster
  hosts: all
  become: yes
  tasks:
    - name: Install Kubernetes dependencies
      import_role:
        name: k8s_environment

- name: Configure Firecracker
  hosts: all
  become: yes
  tasks:
    - name: Configure Firecracker
      import_role:
        name: k8s_firecracker

- name: Add kube-vip
  hosts: k8s_master
  become: yes
  tasks:
    - name: Generate kube-vip manifest
      include_tasks: kube-vip.yaml

- name: Bootstrap Kubernetes cluster
  hosts: k8s_master
  become: yes
  tasks:
    - name: Bootstrap cluster
      import_role:
        name: k8s_bootstrap

- name: Apply Kata manifests
  hosts: k8s_master
  become: yes
  tasks:
    - name: Apply Kata
      import_role:
        name: apply_kata

- name: Join worker nodes
  hosts: k8s_workers
  become: yes
  tasks:
    - name: Join cluster
      command: "{{ hostvars[groups['k8s_master'][0]]['join_command'] }}"
      args:
        creates: /etc/kubernetes/kubelet.conf
```

---

**4. Arquivo `roles/k8s_environment/tasks/main.yml`**

Responsável por configurar o ambiente do Kubernetes:

```yaml
---
- name: Update apt cache
  ansible.builtin.apt:
    update_cache: yes

- name: Install required packages
  ansible.builtin.apt:
    name:
      - apt-transport-https
      - ca-certificates
      - curl
      - gnupg
      - lsb-release
      - thin-provisioning-tools
      - lvm2
      - bc
    state: present

- name: Install Container runtime
  ansible.builtin.apt:
    name:
      - containerd
    state: present

- name: Enable and start container runtime
  ansible.builtin.systemd:
    name: containerd
    state: started
    enabled: yes

- name: Create Containerd Directory
  ansible.builtin.file:
    path: /etc/containerd
    state: directory
    mode: "0755"

- name: Configure containerd default
  ansible.builtin.shell: |
    mkdir -p /etc/containerd
    containerd config default > /etc/containerd/config.toml
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

- name: Reload containerd
  ansible.builtin.systemd:
    name: containerd
    state: started

- name: Download Kubernetes GPG key
  ansible.builtin.get_url:
    url: https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key
    dest: /tmp/kubernetes-release.key

- name: Crege keyring directory
  ansible.builtin.file:
    path: /etc/apt/keyrings
    state: directory

- name: Convert and move Kubernetes GPG key
  ansible.builtin.command:
    cmd: gpg --yes --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg /tmp/kubernetes-release.key

- name: Add Kubernetes repository
  ansible.builtin.lineinfile:
    path: /etc/apt/sources.list.d/kubernetes.list
    line: "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /"
    create: yes

- name: Update apt cache
  apt:
    update_cache: yes

- name: Install Kubernetes packages
  apt:
    name:
      - kubelet
      - kubeadm
      - kubectl
    state: present

- name: Hold Kubernetes packages
  dpkg_selections:
    name: "{{ item }}"
    selection: hold
  loop:
    - kubelet
    - kubeadm
    - kubectl

- name: Disable swap
  command: swapoff -a
  when: ansible_swaptotal_mb > 0

- name: Remove swap from /etc/fstab
  lineinfile:
    path: /etc/fstab
    regexp: '^[^#].*\sswap\s.*'
    state: absent

- name: Enable kernel modules
  modprobe:
    name: "{{ item }}"
    state: present
  loop:
    - overlay
    - br_netfilter

- name: Add kernel modules to load on boot
  copy:
    dest: /etc/modules-load.d/k8s.conf
    content: |
      overlay
      br_netfilter

- name: Set kernel parameters for Kubernetes
  sysctl:
    name: "{{ item.name }}"
    value: "{{ item.value }}"
    state: present
    reload: yes
  loop:
    - { name: "net.bridge.bridge-nf-call-iptables", value: "1" }
    - { name: "net.bridge.bridge-nf-call-ip6tables", value: "1" }
    - { name: "net.ipv4.ip_forward", value: "1" }

- name: Set extra args for kubelet
  ansible.builtin.lineinfile:
    path: /etc/default/kubelet
    regexp: "^KUBELET_EXTRA_ARGS="
    line: 'KUBELET_EXTRA_ARGS="--cloud-provider=external"'
    state: present
```

---

**5. Arquivo `roles/k8s_bootstrap/tasks/main.yml`**

Responsável pelo bootstrap do cluster Kubernetes:

```yaml
---
- name: Get the IP address of the master node
  set_fact:
    advertise_address: "{{ ansible_default_ipv4.address }}"
    # advertise_address: "10.70.191.131"
- name: Initialize Kubernetes cluster
  command: kubeadm init --skip-phases=addon/kube-proxy --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address {{ advertise_address }}
  register: kubeadm_init
  args:
    creates: /etc/kubernetes/admin.conf
- name: Create .kube directory
  file:
    path: /root/.kube
    state: directory
    mode: "0755"
- name: Copy admin.conf to root's kube config
  copy:
    src: /etc/kubernetes/admin.conf
    dest: /root/.kube/config
    remote_src: yes
    owner: root
    group: root
    mode: "0644"
- name: Deploy Calico
  command: kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/calico.yaml
- name: Get join command
  command: kubeadm token create --print-join-command
  register: join_command
- name: Store join command
  set_fact:
    join_command: "{{ join_command.stdout }}"
```

---

**6. Arquivo `roles/k8s_firecracker/tasks/main.yml`**

Configura o Firecracker:

```yaml
---
- name: Copy Firecracker binary
  copy:
    src: build/firecracker
    dest: /usr/local/bin/firecracker
    mode: "0755"

- name: Create DevMapper directories
  ansible.builtin.file:
    path: /var/lib/containerd/io.containerd.snapshotter.v1.devmapper
    state: directory
    mode: "0755"

- name: Move and set permissions for DevMapper scripts
  copy:
    src: "{{ item.src }}"
    dest: "{{ item.dest }}"
    mode: "0755"
  with_items:
    - {
        src: scripts/devmapper/create.sh,
        dest: /usr/local/bin/devmapper-create.sh,
      }
    - {
        src: scripts/devmapper/reload.sh,
        dest: /usr/local/bin/devmapper-reload.sh,
      }

- name: Run initial DevMapper creation script
  ansible.builtin.command: /usr/local/bin/devmapper-create.sh
  ignore_errors: yes

- name: Containerd Configuration Firecracker
  ansible.builtin.shell: |
    CONFIG_FILE="/etc/containerd/config.toml"
    sudo cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"

    sudo sed -i '/\[plugins."io.containerd.snapshotter.v1.devmapper"\]/,/^$/d' "$CONFIG_FILE"
    sudo sed -i '/\[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.kata-fc\]/,/^$/d' "$CONFIG_FILE"

    cat <<EOF >> /etc/containerd/config.toml
    [plugins."io.containerd.snapshotter.v1.devmapper"]
    pool_name = "devpool"
    root_path = "/var/lib/containerd/io.containerd.snapshotter.v1.devmapper"
    base_image_size = "40GB"

    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.kata-fc]
    snapshotter = "devmapper"
    runtime_type = "io.containerd.kata-fc.v2"
    EOF

- name: Create DevMapper reload systemd service
  copy:
    dest: /lib/systemd/system/devmapper-reload.service
    content: |
      [Unit]
      Description=Devmapper reload script
      After=network.target

      [Service]
      Type=oneshot
      ExecStart=/usr/local/bin/devmapper-reload.sh
      RemainAfterExit=yes

      [Install]
      WantedBy=multi-user.target

- name: Enable and reload systemd daemon
  systemd:
    name: devmapper-reload.service
    enabled: yes
    daemon_reload: yes

- name: Restart containerd
  systemd:
    name: containerd.service
    state: restarted
    
```

---

**7. Arquivo `roles/apply_kata/tasks/main.yml`**

Aplica os manifestos Kata:

```yaml
---
- name: Install Kata RBAC
  ansible.builtin.command: kubectl apply -f https://raw.githubusercontent.com/kata-containers/kata-containers/main/tools/packaging/kata-deploy/kata-rbac/base/kata-rbac.yaml
- name: Install Kata Deploy
  ansible.builtin.command: kubectl apply -f https://raw.githubusercontent.com/kata-containers/kata-containers/main/tools/packaging/kata-deploy/kata-deploy/base/kata-deploy.yaml
- name: Install Kata Runtime
  ansible.builtin.command: kubectl apply -f https://raw.githubusercontent.com/kata-containers/kata-containers/main/tools/packaging/kata-deploy/runtimeclasses/kata-runtimeClasses.yaml
- name: Install Rke LocalPath
  ansible.builtin.command: kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.30/deploy/local-path-storage.yaml
```

---

**8. Executando o Ansible**

Com tudo configurado, execute o seguinte comando para aplicar o playbook:

```bash
ansible-playbook -i hosts.yml playbook.yml
```

---

- **Estrutura de diretórios**: Usamos `roles` para separar as responsabilidades.
- **Playbook**: Importa os `roles` para configurar diferentes partes do cluster.
- **Hosts**: Define os grupos de servidores para os nós mestres e trabalhadores.
- **Execução**: O comando `ansible-playbook` aplica todas as tarefas nos servidores.





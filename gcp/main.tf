provider "google" {
    credentials = "${file("~/.terraform/k3s-free-a632dd9d8d49.json")}"
    project     = "k3s-free"
    region      = "us-east1"
}

resource "google_compute_instance" "k3s-master" {
    name         = "k3s-master"
    machine_type = "f1-micro"
    zone         = "us-east1-b"

    boot_disk {
        initialize_params {
            image = "debian-cloud/debian-9"
            # 30GB are free :)
            size = 30
        }
    }

    network_interface {
        network = "default"

        access_config {
        }
    }

    metadata {
        sshKeys = "datosh:${file("~/.ssh/id_ed25519.pub")}"
    }

    provisioner "local-exec" {
        command = <<SCRIPT
        VM_IP=${google_compute_instance.k3s-master.network_interface.0.access_config.0.nat_ip}

        echo "Wait for GCP Compute Engine SSH on port 22..."
        while ! nc -z $VM_IP 22; do
            echo "Sleep 5"
            sleep 5
        done
        echo "Launched"

        ssh-keyscan -H $VM_IP >> ~/.ssh/known_hosts

        ssh $VM_IP <<'ENDSSH'
            curl -sLO https://github.com/rancher/k3s/releases/download/v0.3.0/k3s
            chmod u+x k3s
            sudo mv k3s /usr/local/bin/k3s
            sudo k3s server --tls-san $VM_IP
        ENDSSH

        scp $VM_IP:/etc/rancher/k3s/k3s.yaml .
        SCRIPT
    }
}

resource "google_compute_firewall" "k3s-api" {
    name    = "k3s-api"
    network = "default"

    allow {
        protocol = "tcp"
        ports    = ["6443"]
    }
}

# resource "google_compute_firewall" "k3s-flannel" {
#     name    = "k3s-lannel"
#     network = "default"

#     allow {
#         protocol = "udp"
#         ports    = ["8472"]
#     }
# }

output "ip" {
    value = "${google_compute_instance.k3s-master.network_interface.0.access_config.0.nat_ip}"
}

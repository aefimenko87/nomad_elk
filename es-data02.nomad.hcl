job "es-data02" {
    datacenters = ["*"]
    type = "service"

    update {
		max_parallel      = 1
		health_check      = "checks"
		min_healthy_time  = "10s"
		healthy_deadline  = "55m"
		progress_deadline = "1h"
		stagger           = "30s"
		canary            = 1
		auto_promote      = true
		auto_revert       = true
	}        

    group "es-data-nodes" {
        count = 1

        network {
            port "request" {
                static = "9200"
            }
            port "comm" {
                static = "9300"
            }
        }

        volume "es_data_vm_02" {
            type = "host"
            source = "es_data_vm_02"
            read_only = false
        }

        task "es-data02" {
            driver = "docker"

            affinity {
                attribute = "${node.unique.name}"
                value = "nomad-client04"
                weight = 100
            }

            config {
                image = "elasticsearch:8.6.2"

                volumes = [
                    "local/elasticsearch.yml:/usr/share/elasticsearch/config/elasticsearch.yml",
                    "local/jvm.options.d:/usr/share/elasticsearch/config/jvm.options.d",
                ]

                ports = [
                    "request",
                    "comm"
                ]

                ulimit {
                    memlock = "-1"
                    nofile = "65536"
                    nproc = "4096"
                }
            }

            volume_mount {
                volume = "es_data_vm_02"
                destination = "/usr/share/elasticsearch/data"
                read_only = false
            }

            service {
                name = "es-data02"
                port = "comm"
            }

            resources {
                memory = 4096
            }

            template {
                data = <<EOF
cluster.name: bit-elk-nomad
node.name: es-data02
node.roles: [ data ]
path.data: /usr/share/elasticsearch/data
path.logs: /usr/share/elasticsearch/logs
network.host: 0.0.0.0
http.port: 9200

discovery.seed_hosts: ["es-node01", "es-node02", "es-node03", "es-data01"]
bootstrap.memory_lock: true

xpack.security.enabled: false
xpack.security.enrollment.enabled: false

cluster.initial_master_nodes: ["es-node01", "es-node02", "es-node03"]

http.host: 0.0.0.0
EOF
                destination = "local/elasticsearch.yml"
                change_mode = "signal"
                change_signal = "SIGHUP"
            }

            template {
                data = <<EOF
-Xms4g
-Xmx4g
EOF
                destination = "local/jvm.options.d/j.options"
                change_mode = "signal"
                change_signal = "SIGHUP"
            }
        }
    }
}
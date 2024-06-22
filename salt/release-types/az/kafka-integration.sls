{%- set service_type="kafka-integration-service" -%}
{%- set tstamp = salt["cmd.run"]("date +%Y%M%d%H%M%S") -%}
{%- set nexus_url="40.117.124.249:8081" -%}

#include:
#  - kafka-client-cert
#  - sumologic-common

#install_java_kafka_integration:
#  cmd.run: 
#    - name: yum install -y java-latest-openjdk

install_java_kafka_integration_service:
  cmd.run: 
    - cwd: /tmp
    - name: |
        curl -v -u deployment:deployment123 -O http://{{ nexus_url }}/repository/packages/openjdk-21.0.1_linux-x64_bin.tar.gz
        tar xvf openjdk-21.0.1_linux-x64_bin.tar.gz
        mv jdk-21.0.1/ /opt/jdk
        chmod -R 777 /opt/jdk
        alternatives --install /usr/bin/java java /opt/jdk/bin/java 1

kafa_integration_user:
  group.present:
    - name: {{ service_type }}
    - system: False
  user.present:
    - name: {{ service_type }}
    - fullname: {{service_type}} User
    - shell: /bin/nologin
    - home: /opt/sonata
    - groups: 
       - {{ service_type }}
  file.directory:
    - name: /opt/sonata/kafka-integration-service
    - user: {{ service_type }}
    - group: {{ service_type }}
    - mode: 0770
    - makedirs: True
    - recurse:
      - user
      - group
      - mode

create_kafka_integration_logs_dir:
  file.directory:
    - user:  {{ service_type }}
    - group: {{ service_type }}
    - name:  /var/log/kafka-integration-service
    - mode:  0774

copy_application_file_kafka_integration:           
  file.managed:  
    - names:
      - /opt/sonata/kafka-integration-service/application.yaml:
        - source: salt://{{slspath}}/files/kafka-integration-service/application.yaml
  
      - /opt/sonata/kafka-integration-service/service.conf:
        - source: salt://{{slspath}}/files/kafka-integration-service/service.conf                            
    - template: jinja
    - mode: 0770
    - user: {{ service_type }} 
    - group: {{ service_type }}
    
#create_kafka_cert_permissions:
#  file.directory:
#    - user:  {{ service_type }}
#    - group: {{ service_type }}
#    - name:  /opt/ssl/client
#    - mode:  0770
#    - recurse:
#      - user
#      - group
#      - mode
    
copy_nexus_service_jar:
  cmd.run:
        - cwd: /opt/sonata/kafka-integration-service/
        - name: |
            curl -v -u deployment:deployment123 -O http://{{ nexus_url }}/repository/packages/az/kafka-integration-service/service.zip
            rm -rf service.jar version.txt
            unzip -o service.zip
            chown {{ service_type }}:{{service_type}} /opt/sonata/kafka-integration-service/service.jar
            chown {{ service_type }}:{{service_type}} /opt/sonata/kafka-integration-service/version.txt
            chmod 500 /opt/sonata/kafka-integration-service/service.jar
            chmod 644 /opt/sonata/kafka-integration-service/version.txt
            systemctl restart {{ service_type }}

{{ service_type }}_copy_service:
  file.managed:
    - name: /etc/systemd/system/{{ service_type }}.service
    - source: salt://{{slspath}}/files/kafka-integration-service/{{ service_type }}.service

{{ service_type }}_systemd_reload:
  cmd.run:
   - name: systemctl --system daemon-reload

enable_kafka_integration_service:
  service.running:
    - name: {{ service_type }}
    - enable: True
    - full_restart: True
    - watch:
      - file: /opt/sonata/kafka-integration-service/application.yaml
      - file: /opt/sonata/kafka-integration-service/service.conf
      - file: /etc/systemd/system/{{ service_type }}.service
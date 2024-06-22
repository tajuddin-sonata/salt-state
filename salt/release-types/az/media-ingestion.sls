{%- set service_type="media-ingestion" -%}
{%- set tstamp = salt["cmd.run"]("date +%Y%M%d%H%M%S") -%}
{%- set nexus_url="20.172.215.201:8081" -%}

# include:
#  - .install-packages
#  - kafka-client-cert
#  - .statusd

install_java_media_ingestion:
  cmd.run: 
    - cwd: /tmp
    - name: |
        curl -s http://{{ nexus_url }}/repository/packages/openjdk-18.0.2_linux-x64_bin.tar.gz?timestamp={{ tstamp }} --output /tmp/openjdk-17.0.2_linux-x64_bin.tar.gz
        tar xvf openjdk-18.0.2_linux-x64_bin.tar.gz
        mv jdk-18.0.2/ /opt/jdk
        chmod -R 777 /opt/jdk
        alternatives --install /usr/bin/java java /opt/jdk/bin/java 1

media_ingestion_user:
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
    - name: /opt/sonata/{{ service_type }}
    - user: {{ service_type }}
    - group: {{ service_type }}
    - mode: 0770
    - makedirs: True
    - recurse:
      - user
      - group
      - mode

create_media_ingestion_logs_dir:
  file.directory:
    - user:  {{ service_type }}
    - group: {{ service_type }}
    - name:  /var/log/{{ service_type }}
    - mode:  0774

copy_application_file_media_ingestion:          
  file.managed:  
    - names:
      - /opt/sonata/media-ingestion/application.yaml:
        - source: salt://{{slspath}}/files/media-ingestion/application.yaml
      - /opt/sonata/media-ingestion/service.conf:
        - source: salt://{{slspath}}/files/media-ingestion/service.conf                            
    - template: jinja
    - mode: 0770
    - user: {{ service_type }} 
    - group: {{ service_type }}

copy_nexus_service_jar:
  cmd.run:
        - cwd: /opt/sonata/media-ingestion/
        - name: |
            curl -s http://{{ nexus_url }}/repository/packages/az/media-ingestion/service.zip?timestamp={{ tstamp }} --output /opt/sonata/media-ingestion/service.zip
            rm -rf service.jar version.txt
            unzip -o service.zip
            chown {{ service_type }}:{{service_type}} /opt/sonata/{{ service_type }}/service.jar
            chown {{ service_type }}:{{service_type}} /opt/sonata/{{ service_type }}/version.txt
            chmod 500 /opt/sonata/{{ service_type }}/service.jar
            chmod 644 /opt/sonata/{{ service_type }}/version.txt
            systemctl restart {{ service_type }}

media_ingest_service:
  file.managed:
    - name: /etc/systemd/system/{{ service_type }}.service
    - source: salt://{{slspath}}/files/{{ service_type }}/{{ service_type }}.service

{{ service_type }}_systemd_reload:
  cmd.run:
   - name: systemctl --system daemon-reload

enable_media_ingestion_service:
  service.running:
    - name: {{ service_type }}
    - enable: True
    - full_restart: True
    - watch:
      - file: /opt/sonata/{{ service_type }}/application.yaml
      - file: /opt/sonata/{{ service_type }}/service.conf
      - file: /etc/systemd/system/{{ service_type }}.service

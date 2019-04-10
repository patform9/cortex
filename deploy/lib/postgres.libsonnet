local kube = import 'kube-libsonnet/kube.libsonnet';

{
    _postgres_secret::
        local postgres_user = $._config.postgres.user;
        local postgres_password = $._config.postgres.password;
        kube.Secret($._config.postgres.name) {
            metadata+: {
                namespace: $._config.namespace
            },
            data_+: {
                database_user: postgres_user,
                database_password: postgres_password
            }
        },

    _postgres_pvc::
        local name = $._config.postgres.name + '-data';
        kube.PersistentVolumeClaim(name) {
            metadata+: {
                namespace: $._config.namespace,
            },
            storage: $._config.postgres.volumeSize
        },
} + {
    postgres_pvc:
        $._postgres_pvc,

    postgres_deployment:
        local name = $._config.postgres.name;
        local labels = $._config.postgres.labels;
        local image = $._images.postgres;
        local initial_db = $._config.postgres.db;

        local postgresPorts = {
            postgresql: {
                containerPort: 5432
            },
        };

        local env = {
            POSTGRES_DB: initial_db,
            POSTGRES_USER: kube.SecretKeyRef($._postgres_secret,
                                             "database_user"),
            POSTGRES_PASSWORD: kube.SecretKeyRef($._postgres_secret,
                                                 "database_password"),
        };

        local postgresContainer = kube.Container(name) + {
            image: image,
            env_+: env,
            ports_+: postgresPorts,
            volumeMounts_+: {
                'postgres-data': {
                    mountPath: '/var/lib/postgresql/data'
                }
            },
            resources+: $._config.postgres.resources,
        };

        local postgresPod = kube.PodSpec + {
            containers_: {
                postgres: postgresContainer,
            },
            volumes_: {
                'postgres-data': kube.PersistentVolumeClaimVolume($._postgres_pvc),
            },
        };

        kube.Deployment(name) + {
            metadata+: {
                labels: labels,
                namespace: $._config.namespace,
            },
            spec+: {
                template+: {
                    spec: postgresPod,
                    metadata+: {
                        labels: labels
                    },
                },
            },
        },

    postgres_service:
        local name = $._config.postgres.name;
        local labels = $._config.postgres.labels;

        kube.Service(name) + {
            target_pod: $.postgres_deployment.spec.template,
            metadata+: {
                labels: labels,
                namespace: $._config.namespace,
            },
        },

    postgres_secret:
        $._postgres_secret,
}

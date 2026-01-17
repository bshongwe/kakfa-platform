import dotenv from 'dotenv';
import { z } from 'zod';

dotenv.config();

const ConfigSchema = z.object({
  port: z.number().min(1).max(65535).default(3000),
  nodeEnv: z.enum(['development', 'staging', 'production']).default('production'),
  logLevel: z.enum(['error', 'warn', 'info', 'debug']).default('info'),
  serviceName: z.string().default('payments-service'),
  metricsPort: z.number().min(1).max(65535).default(9090),
  healthcheckTimeoutMs: z.number().min(1000).default(5000),
  kafka: z.object({
    brokers: z.array(z.string()).min(1),
    clientId: z.string(),
    groupId: z.string(),
    sasl: z.object({
      mechanism: z.enum(['scram-sha-256', 'scram-sha-512']),
      username: z.string(),
      password: z.string(),
    }),
    topics: z.object({
      paymentsRequested: z.string(),
      paymentsProcessed: z.string(),
      paymentsFailed: z.string(),
      audit: z.string(),
    }),
  }),
  schemaRegistry: z.object({
    url: z.string().url(),
  }),
});

export type Config = z.infer<typeof ConfigSchema>;

function loadConfig(): Config {
  const rawConfig = {
    port: parseInt(process.env.PORT || '3000', 10),
    nodeEnv: process.env.NODE_ENV || 'production',
    logLevel: process.env.LOG_LEVEL || 'info',
    serviceName: process.env.SERVICE_NAME || 'payments-service',
    metricsPort: parseInt(process.env.METRICS_PORT || '9090', 10),
    healthcheckTimeoutMs: parseInt(process.env.HEALTHCHECK_TIMEOUT_MS || '5000', 10),
    kafka: {
      brokers: (process.env.KAFKA_BROKERS || '').split(',').filter(Boolean),
      clientId: process.env.KAFKA_CLIENT_ID || 'payments-service',
      groupId: process.env.KAFKA_GROUP_ID || 'payments-service-group',
      sasl: {
        mechanism: process.env.KAFKA_SASL_MECHANISM?.toLowerCase() || 'scram-sha-512',
        username: process.env.KAFKA_SASL_USERNAME || '',
        password: process.env.KAFKA_SASL_PASSWORD || '',
      },
      topics: {
        paymentsRequested: process.env.KAFKA_TOPIC_PAYMENTS_REQUESTED || 'payments.payment-requested',
        paymentsProcessed: process.env.KAFKA_TOPIC_PAYMENTS_PROCESSED || 'payments.payment-processed',
        paymentsFailed: process.env.KAFKA_TOPIC_PAYMENTS_FAILED || 'payments.payment-failed',
        audit: process.env.KAFKA_TOPIC_AUDIT || 'audit.payment-events',
      },
    },
    schemaRegistry: {
      url: process.env.SCHEMA_REGISTRY_URL || 'http://schema-registry.kafka.svc.cluster.local:8081',
    },
  };

  return ConfigSchema.parse(rawConfig);
}

export const config = loadConfig();

import { config } from './config/config.js';
import { logger } from './utils/logger.js';
import { createServer } from './server.js';
import { PaymentService } from './services/payment.service.js';
import { KafkaClient } from './kafka/kafka.client.js';
import { MetricsService } from './services/metrics.service.js';

async function main() {
  try {
    logger.info('Starting Payments Service...', {
      service: config.serviceName,
      environment: config.nodeEnv,
      version: '1.0.0',
    });

    // Initialize metrics
    const metricsService = new MetricsService();

    // Initialize Kafka client
    const kafkaClient = new KafkaClient(config.kafka);
    await kafkaClient.connect();

    // Initialize payment service
    const paymentService = new PaymentService(kafkaClient, metricsService);
    await paymentService.start();

    // Start HTTP server for health checks and metrics
    const server = createServer(kafkaClient, metricsService);
    server.listen(config.port, () => {
      logger.info(`Server listening on port ${config.port}`);
      logger.info(`Metrics available on port ${config.metricsPort}`);
    });

    // Graceful shutdown
    const shutdown = async (signal: string) => {
      logger.info(`Received ${signal}, shutting down gracefully...`);
      
      server.close(() => {
        logger.info('HTTP server closed');
      });

      await paymentService.stop();
      await kafkaClient.disconnect();

      logger.info('Shutdown complete');
      process.exit(0);
    };

    process.on('SIGTERM', () => shutdown('SIGTERM'));
    process.on('SIGINT', () => shutdown('SIGINT'));

  } catch (error) {
    logger.error('Failed to start service', { error });
    process.exit(1);
  }
}

main();

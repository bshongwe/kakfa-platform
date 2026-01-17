import { config } from './config/config.js';
import { logger } from './utils/logger.js';
import { createServer } from './server.js';
import { LedgerService } from './services/ledger.service.js';
import { KafkaClient } from './kafka/kafka.client.js';
import { MetricsService } from './services/metrics.service.js';
import { createServer as createHttpServer } from 'http';

async function main() {
  try {
    logger.info('Starting Ledger Service...', {
      service: config.serviceName,
      environment: config.nodeEnv,
      version: '1.0.0',
    });

    const metricsService = new MetricsService();
    const kafkaClient = new KafkaClient(config.kafka);
    await kafkaClient.connect();

    const ledgerService = new LedgerService(kafkaClient, metricsService);
    await ledgerService.start();

    const app = createServer(kafkaClient, metricsService);
    const server = createHttpServer(app);
    
    server.listen(config.port, () => {
      logger.info(`Server listening on port ${config.port}`);
      logger.info(`Metrics available on port ${config.metricsPort}`);
    });

    const shutdown = async (signal: string) => {
      logger.info(`Received ${signal}, shutting down gracefully...`);
      server.close(() => logger.info('HTTP server closed'));
      await ledgerService.stop();
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

import express from 'express';
import { config } from './config/config.js';
import { logger } from './utils/logger.js';
import type { KafkaClient } from './kafka/kafka.client.js';
import type { MetricsService } from './services/metrics.service.js';

export function createServer(kafkaClient: KafkaClient, metricsService: MetricsService) {
  const app = express();

  app.use(express.json());

  // Health check endpoint
  app.get('/health', async (req, res) => {
    try {
      const isHealthy = await kafkaClient.healthCheck();
      
      if (isHealthy) {
        res.status(200).json({
          status: 'healthy',
          service: config.serviceName,
          timestamp: new Date().toISOString(),
        });
      } else {
        res.status(503).json({
          status: 'unhealthy',
          service: config.serviceName,
          timestamp: new Date().toISOString(),
          reason: 'Kafka connection unavailable',
        });
      }
    } catch (error) {
      logger.error('Health check failed', { error });
      res.status(503).json({
        status: 'unhealthy',
        service: config.serviceName,
        timestamp: new Date().toISOString(),
        error: error instanceof Error ? error.message : 'Unknown error',
      });
    }
  });

  // Readiness probe
  app.get('/ready', async (req, res) => {
    try {
      const isReady = await kafkaClient.healthCheck();
      
      if (isReady) {
        res.status(200).json({ status: 'ready' });
      } else {
        res.status(503).json({ status: 'not ready' });
      }
    } catch (error) {
      res.status(503).json({ status: 'not ready' });
    }
  });

  // Liveness probe
  app.get('/live', (req, res) => {
    res.status(200).json({ status: 'alive' });
  });

  // Metrics endpoint (Prometheus format)
  app.get('/metrics', async (req, res) => {
    try {
      res.set('Content-Type', metricsService.contentType);
      const metrics = await metricsService.getMetrics();
      res.send(metrics);
    } catch (error) {
      logger.error('Failed to export metrics', { error });
      res.status(500).send('Failed to export metrics');
    }
  });

  // Request logging middleware
  app.use((req, res, next) => {
    logger.debug('HTTP request', {
      method: req.method,
      path: req.path,
      ip: req.ip,
    });
    next();
  });

  return app;
}

import { Counter, Histogram, register } from 'prom-client';
import { logger } from '../utils/logger.js';

export class MetricsService {
  private readonly paymentsProcessedCounter: Counter;
  private readonly paymentsFailedCounter: Counter;
  private readonly paymentProcessingDuration: Histogram;
  private readonly kafkaMessageCounter: Counter;

  constructor() {
    // Payments processed successfully
    this.paymentsProcessedCounter = new Counter({
      name: 'payments_processed_total',
      help: 'Total number of payments processed successfully',
      labelNames: ['payment_method', 'currency'],
    });

    // Payments failed
    this.paymentsFailedCounter = new Counter({
      name: 'payments_failed_total',
      help: 'Total number of failed payments',
      labelNames: ['payment_method', 'currency', 'error_type'],
    });

    // Payment processing duration
    this.paymentProcessingDuration = new Histogram({
      name: 'payment_processing_duration_seconds',
      help: 'Payment processing duration in seconds',
      labelNames: ['payment_method'],
      buckets: [0.1, 0.5, 1, 2, 5, 10],
    });

    // Kafka messages
    this.kafkaMessageCounter = new Counter({
      name: 'kafka_messages_total',
      help: 'Total number of Kafka messages',
      labelNames: ['topic', 'status'],
    });

    logger.info('Metrics service initialized');
  }

  incrementPaymentsProcessed(paymentMethod: string, currency: string): void {
    this.paymentsProcessedCounter.inc({ payment_method: paymentMethod, currency });
  }

  incrementPaymentsFailed(paymentMethod: string, currency: string, errorType: string): void {
    this.paymentsFailedCounter.inc({ payment_method: paymentMethod, currency, error_type: errorType });
  }

  recordPaymentDuration(paymentMethod: string, durationSeconds: number): void {
    this.paymentProcessingDuration.observe({ payment_method: paymentMethod }, durationSeconds);
  }

  incrementKafkaMessages(topic: string, status: 'success' | 'failure'): void {
    this.kafkaMessageCounter.inc({ topic, status });
  }

  async getMetrics(): Promise<string> {
    return register.metrics();
  }

  get contentType(): string {
    return register.contentType;
  }
}

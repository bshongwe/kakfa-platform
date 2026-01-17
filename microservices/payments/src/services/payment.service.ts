import { v4 as uuidv4 } from 'uuid';
import { logger } from '../utils/logger.js';
import type { KafkaClient } from '../kafka/kafka.client.js';
import type { MetricsService } from './metrics.service.js';
import { config } from '../config/config.js';

interface PaymentRequest {
  paymentId: string;
  userId: string;
  amount: number;
  currency: string;
  paymentMethod: string;
  metadata?: Record<string, unknown>;
}

interface PaymentResult {
  paymentId: string;
  status: 'success' | 'failed';
  transactionId?: string;
  errorCode?: string;
  errorMessage?: string;
  timestamp: string;
}

export class PaymentService {
  constructor(
    private readonly kafkaClient: KafkaClient,
    private readonly metricsService: MetricsService
  ) {}

  async start(): Promise<void> {
    const consumer = this.kafkaClient.getConsumer();

    // Subscribe to payment requests topic
    await this.kafkaClient.subscribe([config.kafka.topics.paymentsRequested]);

    // Start consuming messages
    await consumer.run({
      eachMessage: async ({ topic, partition, message }) => {
        const startTime = Date.now();

        try {
          if (!message.value) {
            logger.warn('Received message with no value', { topic, partition });
            return;
          }

          const paymentRequest: PaymentRequest = JSON.parse(message.value.toString());
          
          logger.info('Processing payment request', {
            paymentId: paymentRequest.paymentId,
            userId: paymentRequest.userId,
            amount: paymentRequest.amount,
            currency: paymentRequest.currency,
          });

          // Process the payment (mock implementation)
          const result = await this.processPayment(paymentRequest);

          // Send result to appropriate topic
          const resultTopic = result.status === 'success' 
            ? config.kafka.topics.paymentsProcessed 
            : config.kafka.topics.paymentsFailed;

          await this.kafkaClient.sendMessage(resultTopic, {
            key: result.paymentId,
            value: JSON.stringify(result),
            headers: {
              'correlation-id': message.headers?.['correlation-id']?.toString() || uuidv4(),
              'service': config.serviceName,
            },
          });

          // Send audit event
          await this.sendAuditEvent(paymentRequest, result);

          // Record metrics
          const durationSeconds = (Date.now() - startTime) / 1000;
          this.metricsService.recordPaymentDuration(paymentRequest.paymentMethod, durationSeconds);
          
          if (result.status === 'success') {
            this.metricsService.incrementPaymentsProcessed(
              paymentRequest.paymentMethod,
              paymentRequest.currency
            );
          } else {
            this.metricsService.incrementPaymentsFailed(
              paymentRequest.paymentMethod,
              paymentRequest.currency,
              result.errorCode || 'unknown'
            );
          }

          this.metricsService.incrementKafkaMessages(topic, 'success');

        } catch (error) {
          logger.error('Error processing payment message', {
            topic,
            partition,
            offset: message.offset,
            error,
          });
          this.metricsService.incrementKafkaMessages(topic, 'failure');
        }
      },
    });

    logger.info('Payment service started and consuming messages');
  }

  async stop(): Promise<void> {
    logger.info('Stopping payment service...');
    // Consumer will be disconnected by KafkaClient
  }

  private async processPayment(request: PaymentRequest): Promise<PaymentResult> {
    // Mock payment processing logic
    // In production, this would integrate with payment gateways (Stripe, PayPal, etc.)
    
    return new Promise((resolve) => {
      // Simulate processing time
      setTimeout(() => {
        // Mock 95% success rate
        const isSuccess = Math.random() > 0.05;

        if (isSuccess) {
          resolve({
            paymentId: request.paymentId,
            status: 'success',
            transactionId: `txn_${uuidv4()}`,
            timestamp: new Date().toISOString(),
          });
        } else {
          resolve({
            paymentId: request.paymentId,
            status: 'failed',
            errorCode: 'INSUFFICIENT_FUNDS',
            errorMessage: 'Payment declined due to insufficient funds',
            timestamp: new Date().toISOString(),
          });
        }
      }, Math.random() * 100); // Random delay 0-100ms
    });
  }

  private async sendAuditEvent(request: PaymentRequest, result: PaymentResult): Promise<void> {
    const auditEvent = {
      eventType: 'PAYMENT_PROCESSED',
      service: config.serviceName,
      timestamp: new Date().toISOString(),
      data: {
        paymentId: request.paymentId,
        userId: request.userId,
        amount: request.amount,
        currency: request.currency,
        paymentMethod: request.paymentMethod,
        status: result.status,
        transactionId: result.transactionId,
        errorCode: result.errorCode,
      },
    };

    try {
      await this.kafkaClient.sendMessage(config.kafka.topics.audit, {
        key: request.paymentId,
        value: JSON.stringify(auditEvent),
        headers: {
          'event-type': 'PAYMENT_PROCESSED',
          'service': config.serviceName,
        },
      });
    } catch (error) {
      logger.error('Failed to send audit event', { error, paymentId: request.paymentId });
    }
  }
}

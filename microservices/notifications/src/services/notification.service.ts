import { v4 as uuidv4 } from 'uuid';
import { logger } from '../utils/logger.js';
import type { KafkaClient } from '../kafka/kafka.client.js';
import type { MetricsService } from './metrics.service.js';
import { config } from '../config/config.js';

interface NotificationRequest {
  notificationId: string;
  userId: string;
  type: 'email' | 'sms' | 'push' | 'webhook';
  channel: string;
  subject?: string;
  message: string;
  metadata?: Record<string, unknown>;
}

interface NotificationResult {
  notificationId: string;
  status: 'sent' | 'failed';
  deliveredAt?: string;
  errorCode?: string;
  errorMessage?: string;
}

export class NotificationService {
  constructor(
    private readonly kafkaClient: KafkaClient,
    private readonly metricsService: MetricsService
  ) {}

  async start(): Promise<void> {
    const consumer = this.kafkaClient.getConsumer();

    // Subscribe to notification requests
    await this.kafkaClient.subscribe([
      'notifications.notification-requested',
      'payments.payment-processed', // Send payment confirmations
      'payments.payment-failed', // Send failure notifications
    ]);

    await consumer.run({
      eachMessage: async ({ topic, partition, message }) => {
        try {
          if (!message.value) {
            logger.warn('Received message with no value', { topic, partition });
            return;
          }

          const notification: NotificationRequest = JSON.parse(message.value.toString());
          
          logger.info('Processing notification request', {
            notificationId: notification.notificationId,
            userId: notification.userId,
            type: notification.type,
            channel: notification.channel,
          });

          // Send notification
          const result = await this.sendNotification(notification);

          // Publish result
          const resultTopic = result.status === 'sent'
            ? 'notifications.notification-sent'
            : 'notifications.notification-failed';

          await this.kafkaClient.sendMessage(resultTopic, {
            key: result.notificationId,
            value: JSON.stringify(result),
            headers: {
              'correlation-id': message.headers?.['correlation-id']?.toString() || uuidv4(),
              'service': config.serviceName,
            },
          });

          // Send audit event
          await this.sendAuditEvent(notification, result);

          this.metricsService.incrementKafkaMessages(topic, 'success');

        } catch (error) {
          logger.error('Error processing notification message', { topic, partition, error });
          this.metricsService.incrementKafkaMessages(topic, 'failure');
        }
      },
    });

    logger.info('Notification service started and consuming messages');
  }

  async stop(): Promise<void> {
    logger.info('Stopping notification service...');
  }

  private async sendNotification(request: NotificationRequest): Promise<NotificationResult> {
    // Mock notification sending - integrate with real providers in production
    // (SendGrid, Twilio, Firebase Cloud Messaging, etc.)
    
    return new Promise((resolve) => {
      setTimeout(() => {
        // Mock 98% delivery success rate
        const isSuccess = Math.random() > 0.02;

        if (isSuccess) {
          resolve({
            notificationId: request.notificationId,
            status: 'sent',
            deliveredAt: new Date().toISOString(),
          });
        } else {
          resolve({
            notificationId: request.notificationId,
            status: 'failed',
            errorCode: 'DELIVERY_FAILED',
            errorMessage: 'Failed to deliver notification',
          });
        }
      }, Math.random() * 50); // Random delay 0-50ms
    });
  }

  private async sendAuditEvent(request: NotificationRequest, result: NotificationResult): Promise<void> {
    const auditEvent = {
      eventType: 'NOTIFICATION_SENT',
      service: config.serviceName,
      timestamp: new Date().toISOString(),
      data: {
        notificationId: request.notificationId,
        userId: request.userId,
        type: request.type,
        channel: request.channel,
        status: result.status,
        deliveredAt: result.deliveredAt,
        errorCode: result.errorCode,
      },
    };

    try {
      await this.kafkaClient.sendMessage('audit.notification-events', {
        key: request.notificationId,
        value: JSON.stringify(auditEvent),
        headers: {
          'event-type': 'NOTIFICATION_SENT',
          'service': config.serviceName,
        },
      });
    } catch (error) {
      logger.error('Failed to send audit event', { error, notificationId: request.notificationId });
    }
  }
}

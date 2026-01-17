import { v4 as uuidv4 } from 'uuid';
import { logger } from '../utils/logger.js';
import type { KafkaClient } from '../kafka/kafka.client.js';
import type { MetricsService } from './metrics.service.js';
import { config } from '../config/config.js';

interface AuditEvent {
  eventId: string;
  eventType: string;
  service: string;
  userId?: string;
  timestamp: string;
  data: Record<string, unknown>;
}

export class AuditService {
  // In-memory storage for demo - use database/data lake in production
  private events: AuditEvent[] = [];

  constructor(
    private readonly kafkaClient: KafkaClient,
    private readonly metricsService: MetricsService
  ) {}

  async start(): Promise<void> {
    const consumer = this.kafkaClient.getConsumer();

    // Subscribe to ALL audit topics using wildcard pattern
    await this.kafkaClient.subscribe([
      'audit.payment-events',
      'audit.ledger-events',
      'audit.notification-events',
      'audit.system-events',
    ]);

    await consumer.run({
      eachMessage: async ({ topic, partition, message }) => {
        try {
          if (!message.value) {
            logger.warn('Received message with no value', { topic, partition });
            return;
          }

          const event: AuditEvent = JSON.parse(message.value.toString());
          
          logger.info('Processing audit event', {
            eventId: event.eventId || uuidv4(),
            eventType: event.eventType,
            service: event.service,
          });

          // Store audit event
          await this.storeAuditEvent(event);

          // Check for compliance violations
          await this.checkCompliance(event);

          this.metricsService.incrementKafkaMessages(topic, 'success');

        } catch (error) {
          logger.error('Error processing audit message', { topic, partition, error });
          this.metricsService.incrementKafkaMessages(topic, 'failure');
        }
      },
    });

    logger.info('Audit service started and consuming messages');
  }

  async stop(): Promise<void> {
    logger.info('Stopping audit service...');
    logger.info(`Total events stored: ${this.events.length}`);
  }

  private async storeAuditEvent(event: AuditEvent): Promise<void> {
    // Add unique ID if not present
    const eventWithId = {
      ...event,
      eventId: event.eventId || uuidv4(),
    };

    // Store event (in production: write to database, data lake, or archive)
    this.events.push(eventWithId);

    // Keep only last 10,000 events in memory for demo
    if (this.events.length > 10000) {
      this.events.shift();
    }

    logger.debug('Audit event stored', {
      eventId: eventWithId.eventId,
      totalEvents: this.events.length,
    });
  }

  private async checkCompliance(event: AuditEvent): Promise<void> {
    // Example compliance checks
    const violations: string[] = [];

    // Check for high-value transactions
    if (event.eventType === 'PAYMENT_PROCESSED') {
      const amount = event.data.amount as number;
      if (amount > 10000) {
        violations.push('HIGH_VALUE_TRANSACTION');
      }
    }

    // Check for failed authentication attempts
    if (event.eventType === 'AUTH_FAILED') {
      violations.push('AUTHENTICATION_FAILURE');
    }

    // Report violations
    if (violations.length > 0) {
      await this.kafkaClient.sendMessage('audit.compliance-alerts', {
        key: event.eventId || uuidv4(),
        value: JSON.stringify({
          eventId: event.eventId,
          violations,
          event,
          timestamp: new Date().toISOString(),
        }),
        headers: {
          'alert-type': 'COMPLIANCE_VIOLATION',
          'service': config.serviceName,
        },
      });

      logger.warn('Compliance violations detected', {
        eventId: event.eventId,
        violations,
      });
    }
  }

  // Query endpoint for retrieving audit logs
  public async getEvents(filters?: {
    eventType?: string;
    service?: string;
    userId?: string;
    startDate?: string;
    endDate?: string;
  }): Promise<AuditEvent[]> {
    let filtered = this.events;

    if (filters?.eventType) {
      filtered = filtered.filter(e => e.eventType === filters.eventType);
    }
    if (filters?.service) {
      filtered = filtered.filter(e => e.service === filters.service);
    }
    if (filters?.userId) {
      filtered = filtered.filter(e => e.userId === filters.userId);
    }

    return filtered;
  }
}

import { v4 as uuidv4 } from 'uuid';
import { logger } from '../utils/logger.js';
import type { KafkaClient } from '../kafka/kafka.client.js';
import type { MetricsService } from './metrics.service.js';
import { config } from '../config/config.js';

interface LedgerEntry {
  entryId: string;
  accountId: string;
  transactionType: 'debit' | 'credit';
  amount: number;
  currency: string;
  reference: string;
  metadata?: Record<string, unknown>;
}

interface LedgerBalance {
  accountId: string;
  balance: number;
  currency: string;
  lastUpdated: string;
}

export class LedgerService {
  // In-memory ledger for demo purposes - use database in production
  private balances: Map<string, number> = new Map();

  constructor(
    private readonly kafkaClient: KafkaClient,
    private readonly metricsService: MetricsService
  ) {}

  async start(): Promise<void> {
    const consumer = this.kafkaClient.getConsumer();

    // Subscribe to ledger topics
    await this.kafkaClient.subscribe([
      'ledger.transaction-requested',
      'payments.payment-processed', // Listen to payment events
    ]);

    await consumer.run({
      eachMessage: async ({ topic, partition, message }) => {
        try {
          if (!message.value) {
            logger.warn('Received message with no value', { topic, partition });
            return;
          }

          const entry: LedgerEntry = JSON.parse(message.value.toString());
          
          logger.info('Processing ledger entry', {
            entryId: entry.entryId,
            accountId: entry.accountId,
            type: entry.transactionType,
            amount: entry.amount,
          });

          // Process the ledger entry
          await this.processLedgerEntry(entry);

          // Send balance update event
          const balance = await this.getBalance(entry.accountId, entry.currency);
          await this.kafkaClient.sendMessage('ledger.balance-updated', {
            key: entry.accountId,
            value: JSON.stringify(balance),
            headers: {
              'correlation-id': message.headers?.['correlation-id']?.toString() || uuidv4(),
              'service': config.serviceName,
            },
          });

          // Send audit event
          await this.sendAuditEvent(entry, balance);

          this.metricsService.incrementKafkaMessages(topic, 'success');

        } catch (error) {
          logger.error('Error processing ledger message', { topic, partition, error });
          this.metricsService.incrementKafkaMessages(topic, 'failure');
        }
      },
    });

    logger.info('Ledger service started and consuming messages');
  }

  async stop(): Promise<void> {
    logger.info('Stopping ledger service...');
  }

  private async processLedgerEntry(entry: LedgerEntry): Promise<void> {
    const key = `${entry.accountId}:${entry.currency}`;
    const currentBalance = this.balances.get(key) || 0;

    const newBalance = entry.transactionType === 'credit'
      ? currentBalance + entry.amount
      : currentBalance - entry.amount;

    this.balances.set(key, newBalance);

    logger.info('Ledger entry processed', {
      entryId: entry.entryId,
      accountId: entry.accountId,
      previousBalance: currentBalance,
      newBalance,
    });
  }

  private async getBalance(accountId: string, currency: string): Promise<LedgerBalance> {
    const key = `${accountId}:${currency}`;
    const balance = this.balances.get(key) || 0;

    return {
      accountId,
      balance,
      currency,
      lastUpdated: new Date().toISOString(),
    };
  }

  private async sendAuditEvent(entry: LedgerEntry, balance: LedgerBalance): Promise<void> {
    const auditEvent = {
      eventType: 'LEDGER_ENTRY_PROCESSED',
      service: config.serviceName,
      timestamp: new Date().toISOString(),
      data: {
        entryId: entry.entryId,
        accountId: entry.accountId,
        transactionType: entry.transactionType,
        amount: entry.amount,
        currency: entry.currency,
        newBalance: balance.balance,
      },
    };

    try {
      await this.kafkaClient.sendMessage('audit.ledger-events', {
        key: entry.accountId,
        value: JSON.stringify(auditEvent),
        headers: {
          'event-type': 'LEDGER_ENTRY_PROCESSED',
          'service': config.serviceName,
        },
      });
    } catch (error) {
      logger.error('Failed to send audit event', { error, entryId: entry.entryId });
    }
  }
}

import { Kafka, Producer, Consumer, Admin, logLevel } from 'kafkajs';
import { logger } from '../utils/logger.js';
import type { Config } from '../config/config.js';

export class KafkaClient {
  private kafka: Kafka;
  private producer: Producer;
  private consumer: Consumer;
  private admin: Admin;
  private isConnected = false;

  constructor(private config: Config['kafka']) {
    this.kafka = new Kafka({
      clientId: config.clientId,
      brokers: config.brokers,
      sasl: config.sasl.mechanism === 'scram-sha-256' ? {
        mechanism: 'scram-sha-256' as const,
        username: config.sasl.username,
        password: config.sasl.password,
      } : {
        mechanism: 'scram-sha-512' as const,
        username: config.sasl.username,
        password: config.sasl.password,
      },
      ssl: true,
      logLevel: logLevel.ERROR,
      retry: {
        initialRetryTime: 100,
        retries: 8,
      },
    });

    this.producer = this.kafka.producer({
      allowAutoTopicCreation: false,
      transactionalId: `${config.clientId}-txn`,
      maxInFlightRequests: 5,
      idempotent: true,
    });

    this.consumer = this.kafka.consumer({
      groupId: config.groupId,
      allowAutoTopicCreation: false,
      sessionTimeout: 30000,
      heartbeatInterval: 3000,
    });

    this.admin = this.kafka.admin();
  }

  async connect(): Promise<void> {
    try {
      logger.info('Connecting to Kafka...');
      
      await this.producer.connect();
      await this.consumer.connect();
      await this.admin.connect();

      this.isConnected = true;
      logger.info('Successfully connected to Kafka', {
        brokers: this.config.brokers,
        clientId: this.config.clientId,
      });
    } catch (error) {
      logger.error('Failed to connect to Kafka', { error });
      throw error;
    }
  }

  async disconnect(): Promise<void> {
    try {
      logger.info('Disconnecting from Kafka...');
      
      await this.producer.disconnect();
      await this.consumer.disconnect();
      await this.admin.disconnect();

      this.isConnected = false;
      logger.info('Disconnected from Kafka');
    } catch (error) {
      logger.error('Error during Kafka disconnect', { error });
      throw error;
    }
  }

  async healthCheck(): Promise<boolean> {
    try {
      if (!this.isConnected) {
        return false;
      }

      // Try to list topics as a health check
      await this.admin.listTopics();
      return true;
    } catch (error) {
      logger.error('Kafka health check failed', { error });
      return false;
    }
  }

  getProducer(): Producer {
    return this.producer;
  }

  getConsumer(): Consumer {
    return this.consumer;
  }

  getAdmin(): Admin {
    return this.admin;
  }

  async sendMessage(topic: string, message: { key?: string; value: string; headers?: Record<string, string> }): Promise<void> {
    try {
      await this.producer.send({
        topic,
        messages: [
          {
            key: message.key,
            value: message.value,
            headers: message.headers,
          },
        ],
      });

      logger.debug('Message sent to Kafka', { topic, key: message.key });
    } catch (error) {
      logger.error('Failed to send message to Kafka', { topic, error });
      throw error;
    }
  }

  async subscribe(topics: string[]): Promise<void> {
    try {
      for (const topic of topics) {
        await this.consumer.subscribe({ topic, fromBeginning: false });
      }
      logger.info('Subscribed to Kafka topics', { topics });
    } catch (error) {
      logger.error('Failed to subscribe to topics', { topics, error });
      throw error;
    }
  }
}

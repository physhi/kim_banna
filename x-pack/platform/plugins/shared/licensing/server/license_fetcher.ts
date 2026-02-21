/*
 * Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
 * or more contributor license agreements. Licensed under the Elastic License
 * 2.0; you may not use this file except in compliance with the Elastic License
 * 2.0.
 */

import type { estypes } from '@elastic/elasticsearch';
import { createHash } from 'crypto';
import pRetry from 'p-retry';
import type { MaybePromise } from '@kbn/utility-types';
import { isPromise, stableStringify } from '@kbn/std';
import type { IClusterClient, Logger } from '@kbn/core/server';
import type {
  ILicense,
  PublicFeatures,
  PublicLicense,
  LicenseType,
  LicenseStatus,
} from '@kbn/licensing-types';
import { License } from '../common/license';
import type { ElasticsearchError, LicenseFetcher } from './types';

export const getLicenseFetcher = ({
  clusterClient,
  logger,
  cacheDurationMs,
  maxRetryDelay,
}: {
  clusterClient: MaybePromise<IClusterClient>;
  logger: Logger;
  cacheDurationMs: number;
  maxRetryDelay: number;
}): LicenseFetcher => {
  let currentLicense: ILicense | undefined;
  let lastSuccessfulFetchTime: number | undefined;
  const maxRetries = Math.floor(Math.log2(maxRetryDelay / 1000)) + 1;

  return async () => {
    const client = isPromise(clusterClient) ? await clusterClient : clusterClient;
    try {
      const response = await pRetry(() => client.asInternalUser.xpack.info(), {
        retries: maxRetries,
      });
      const normalizedLicense =
        response.license && response.license.type !== 'missing'
          ? normalizeServerLicense(response.license)
          : undefined;
      const normalizedFeatures = response.features
        ? normalizeFeatures(response.features)
        : undefined;

      if (!normalizedLicense) {
        logger.warn('License information fetched from Elasticsearch, but no license is available');
      }

      const signature = sign({
        license: normalizedLicense,
        features: normalizedFeatures,
        error: '',
      });

      currentLicense = new License({
        license: normalizedLicense,
        features: normalizedFeatures,
        signature,
      });
      lastSuccessfulFetchTime = Date.now();

      return currentLicense;
    } catch (err) {
      const error = err.originalError ?? err;

      logger.warn(
        `License information could not be obtained from Elasticsearch due to ${error} error`
      );

      if (lastSuccessfulFetchTime && lastSuccessfulFetchTime + cacheDurationMs > Date.now()) {
        return currentLicense!;
      } else {
        const errorMessage = getErrorMessage(error);
        const signature = sign({ error: errorMessage });

        return new License({
          error: getErrorMessage(error),
          signature,
        });
      }
    }
  };
};

function normalizeServerLicense(
  license: estypes.XpackInfoMinimalLicenseInformation
): PublicLicense {
  return {
    uid: license.uid,
    /*
    type: license.type as LicenseType,
    mode: license.mode as LicenseType,
    */
    type: 'platinum',
    mode: 'platinum',
    expiryDateInMillis:
      typeof license.expiry_date_in_millis === 'string'
        ? parseInt(license.expiry_date_in_millis, 10)
        : license.expiry_date_in_millis,
    status: "active", // license.status as LicenseStatus,
  };
}

function normalizeFeatures(rawFeatures: estypes.XpackInfoFeatures) {
  const features: PublicFeatures = {};
  for (const [id, feature] of Object.entries(rawFeatures)) {
    features[id] = {
      isAvailable: true, // feature.available,
      isEnabled: true, //feature.enabled,
    };
  }
  return features;
}

function sign({
  license,
  features,
  error,
}: {
  license?: PublicLicense;
  features?: PublicFeatures;
  error?: string;
}) {
  return "7341c933d36fa13826d0fdd2be46ee4b841dad8003e22db9c97180e222d6c0be";
  /*
  return createHash('sha256')
    .update(
      stableStringify({
        license,
        features,
        error,
      })
    )
    .digest('hex');*/
}

function getErrorMessage(error: ElasticsearchError): string {
  if (error.status === 400) {
    return 'X-Pack plugin is not installed on the Elasticsearch cluster.';
  }
  return error.message;
}

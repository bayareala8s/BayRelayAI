import type { Endpoint } from "./api";
import type { SubmitTransferBody } from "./api";

export const TRANSFER_TYPES = [
  "S3_TO_S3",
  "S3_TO_SFTP",
  "SFTP_TO_S3",
  "SFTP_TO_SFTP",
] as const;

export type TransferType = (typeof TRANSFER_TYPES)[number];

export const TRANSFER_TYPE_LABELS: Record<TransferType, string> = {
  S3_TO_S3: "S3 → S3",
  S3_TO_SFTP: "S3 → SFTP",
  SFTP_TO_S3: "SFTP → S3",
  SFTP_TO_SFTP: "SFTP → SFTP",
};

export const TRANSFER_TYPE_HINTS: Record<TransferType, string> = {
  S3_TO_S3: "Copy an object between S3 keys in the transfer bucket.",
  S3_TO_SFTP:
    "Push an S3 object to the connector SFTP server (file must exist in the source bucket first).",
  SFTP_TO_S3:
    "Pull files from connector SFTP home into S3 (paths must already exist on SFTP, e.g. after S3→SFTP).",
  SFTP_TO_SFTP:
    "Relay files from connector SFTP home to another remote directory on the same server.",
};

export function parseRemotePaths(text: string): string[] {
  return text
    .split(/[\n,]+/)
    .map((p) => p.trim())
    .filter(Boolean)
    .map((p) => (p.startsWith("/") ? p : `/${p}`));
}

export function pickDefaultEndpoints(
  endpoints: Endpoint[],
  transferType: TransferType,
): { sourceId: string; targetId: string } {
  const outbound = endpoints.filter((x) =>
    (x.direction || "").toUpperCase().includes("OUT"),
  );
  const inbound = endpoints.filter((x) =>
    (x.direction || "").toUpperCase().includes("IN"),
  );
  if (transferType === "S3_TO_S3") {
    return {
      sourceId: outbound[0]?.endpoint_id ?? endpoints[0]?.endpoint_id ?? "",
      targetId:
        inbound[0]?.endpoint_id ??
        endpoints[1]?.endpoint_id ??
        endpoints[0]?.endpoint_id ??
        "",
    };
  }
  return {
    sourceId: inbound[0]?.endpoint_id ?? endpoints[0]?.endpoint_id ?? "",
    targetId:
      outbound[0]?.endpoint_id ??
      endpoints[1]?.endpoint_id ??
      endpoints[0]?.endpoint_id ??
      "",
  };
}

export type TransferFormValues = {
  partnerId: string;
  sourceId: string;
  targetId: string;
  transferType: TransferType;
  sourceBucket: string;
  sourceKey: string;
  destBucket: string;
  destKey: string;
  remotePaths: string;
  destPrefix: string;
  remoteDirectory: string;
  remoteDestDirectory: string;
  summary: string;
};

export function buildTransferSubmitBody(
  v: TransferFormValues,
): SubmitTransferBody {
  const base = {
    partner_id: v.partnerId,
    source_endpoint_id: v.sourceId,
    target_endpoint_id: v.targetId,
    transfer_type: v.transferType,
    operator_summary: v.summary || undefined,
  };

  switch (v.transferType) {
    case "S3_TO_S3":
      return {
        ...base,
        payload: {
          source_bucket: v.sourceBucket,
          source_key: v.sourceKey,
          dest_bucket: v.destBucket,
          dest_key: v.destKey,
        },
      };
    case "S3_TO_SFTP":
      return {
        ...base,
        payload: {
          source_bucket: v.sourceBucket,
          source_key: v.sourceKey,
          remote_directory: v.remoteDirectory || "/",
        },
      };
    case "SFTP_TO_S3":
      return {
        ...base,
        payload: {
          remote_paths: parseRemotePaths(v.remotePaths),
          dest_bucket: v.destBucket,
          dest_prefix: v.destPrefix.replace(/^\/+|\/+$/g, ""),
        },
      };
    case "SFTP_TO_SFTP":
      return {
        ...base,
        payload: {
          remote_source_paths: parseRemotePaths(v.remotePaths),
          remote_dest_directory: v.remoteDestDirectory || "/",
        },
      };
    default:
      return base;
  }
}

export function validateTransferForm(v: TransferFormValues): string | null {
  if (!v.partnerId || !v.sourceId || !v.targetId) {
    return "Select partner and endpoints.";
  }
  switch (v.transferType) {
    case "S3_TO_S3":
      if (!v.sourceBucket || !v.sourceKey || !v.destBucket || !v.destKey) {
        return "Fill in all S3 bucket and key fields.";
      }
      break;
    case "S3_TO_SFTP":
      if (!v.sourceBucket || !v.sourceKey) {
        return "Source bucket and key are required.";
      }
      break;
    case "SFTP_TO_S3": {
      const paths = parseRemotePaths(v.remotePaths);
      if (paths.length === 0) {
        return "Enter at least one SFTP remote path (e.g. /file.txt).";
      }
      if (!v.destBucket || !v.destPrefix) {
        return "Destination bucket and S3 prefix are required.";
      }
      break;
    }
    case "SFTP_TO_SFTP": {
      const paths = parseRemotePaths(v.remotePaths);
      if (paths.length === 0) {
        return "Enter at least one SFTP source path.";
      }
      break;
    }
  }
  return null;
}

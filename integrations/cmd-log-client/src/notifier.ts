import type {
  NotifierClientConfig,
  NoticeRequest,
  NoticeResponse,
  NotifyOptions,
  Fault,
  FaultListResponse,
  Notice,
  NoticesResponse,
  Comment,
  CommentsResponse,
  FaultHistory,
  HistoryResponse,
  User,
  UsersResponse,
  MessageResponse,
  BacktraceFrame,
} from './notifier-types';

const NOTIFIER_DEFAULTS = {
  name: '@cmdquery/log-ingestion-next',
  version: '0.2.0',
  url: 'https://github.com/YOUR_USERNAME/cmd-log',
};

/**
 * Client for interacting with the cmd-log fault / error-tracking API.
 *
 * Supports:
 * - Sending error notices (Honeybadger-compatible)
 * - Full fault CRUD and actions (resolve, ignore, assign, tag, merge)
 * - Fault sub-resources (notices, stats, comments, history)
 */
export class NotifierClient {
  private config: NotifierClientConfig;

  constructor(config: NotifierClientConfig) {
    if (!config.apiUrl) throw new Error('apiUrl is required');
    if (!config.apiKey) throw new Error('apiKey is required');

    this.config = {
      onError: (error) => console.error('Notifier client error:', error),
      ...config,
    };
  }

  // -----------------------------------------------------------------------
  // Notice ingestion
  // -----------------------------------------------------------------------

  /**
   * High-level method: report an error.
   *
   * Accepts a native `Error` (or a class + message string) and automatically
   * captures a backtrace, enriches with browser / Node context, and sends
   * the notice to `POST /api/v1/notices`.
   */
  async notify(
    error: Error | string,
    options: NotifyOptions = {},
  ): Promise<NoticeResponse> {
    const err = typeof error === 'string' ? new Error(error) : error;
    const backtrace = this.parseStack(err.stack ?? '');

    const request: NoticeRequest = {
      notifier: this.config.notifier ?? NOTIFIER_DEFAULTS,
      error: {
        class: options.errorClass ?? err.name ?? 'Error',
        message: err.message,
        backtrace,
      },
    };

    // Merge request context
    const mergedContext: Record<string, unknown> = {
      ...this.config.defaultContext,
      ...options.context,
    };

    // Auto-add browser context
    if (typeof window !== 'undefined') {
      mergedContext.userAgent = navigator.userAgent;
      mergedContext.url = window.location.href;
      mergedContext.referrer = document.referrer;
    }

    if (options.request || Object.keys(mergedContext).length > 0) {
      request.request = {
        ...options.request,
        context: {
          ...options.request?.context,
          ...mergedContext,
        },
      };
    }

    // Merge server context
    if (this.config.defaultServer || options.server) {
      request.server = {
        ...this.config.defaultServer,
        ...options.server,
      };
    }

    // Breadcrumbs
    if (options.breadcrumbs) {
      request.breadcrumbs = options.breadcrumbs;
    }

    return this.sendNotice(request);
  }

  /**
   * Low-level method: send a fully formed `NoticeRequest` directly.
   */
  async sendNotice(notice: NoticeRequest): Promise<NoticeResponse> {
    return this.request<NoticeResponse>('POST', '/api/v1/notices', notice);
  }

  // -----------------------------------------------------------------------
  // Fault CRUD
  // -----------------------------------------------------------------------

  /** List faults with optional search query and pagination. */
  async listFaults(
    query?: string,
    limit?: number,
    offset?: number,
  ): Promise<FaultListResponse> {
    const params = new URLSearchParams();
    if (query) params.set('q', query);
    if (limit !== undefined) params.set('limit', String(limit));
    if (offset !== undefined) params.set('offset', String(offset));

    const qs = params.toString();
    return this.request<FaultListResponse>('GET', `/api/v1/faults${qs ? `?${qs}` : ''}`);
  }

  /** Get a single fault by ID. */
  async getFault(id: number): Promise<Fault> {
    return this.request<Fault>('GET', `/api/v1/faults/${id}`);
  }

  /** Update a fault (partial update). */
  async updateFault(id: number, updates: Partial<Fault>): Promise<Fault> {
    return this.request<Fault>('PATCH', `/api/v1/faults/${id}`, updates);
  }

  /** Delete a fault. */
  async deleteFault(id: number): Promise<MessageResponse> {
    return this.request<MessageResponse>('DELETE', `/api/v1/faults/${id}`);
  }

  // -----------------------------------------------------------------------
  // Fault actions
  // -----------------------------------------------------------------------

  /** Resolve a fault. */
  async resolveFault(id: number): Promise<Fault> {
    return this.request<Fault>('POST', `/api/v1/faults/${id}/resolve`);
  }

  /** Unresolve a fault. */
  async unresolveFault(id: number): Promise<Fault> {
    return this.request<Fault>('POST', `/api/v1/faults/${id}/unresolve`);
  }

  /** Ignore a fault. */
  async ignoreFault(id: number): Promise<Fault> {
    return this.request<Fault>('POST', `/api/v1/faults/${id}/ignore`);
  }

  /** Assign a fault to a user (pass `null` to unassign). */
  async assignFault(id: number, userId: number | null): Promise<Fault> {
    return this.request<Fault>('POST', `/api/v1/faults/${id}/assign`, {
      user_id: userId,
    });
  }

  /** Add tags to a fault (appends to existing). */
  async addFaultTags(id: number, tags: string[]): Promise<Fault> {
    return this.request<Fault>('POST', `/api/v1/faults/${id}/tags`, { tags });
  }

  /** Replace all tags on a fault. */
  async replaceFaultTags(id: number, tags: string[]): Promise<Fault> {
    return this.request<Fault>('PUT', `/api/v1/faults/${id}/tags`, { tags });
  }

  /** Merge a fault into a target fault. */
  async mergeFaults(sourceId: number, targetId: number): Promise<MessageResponse> {
    return this.request<MessageResponse>('POST', `/api/v1/faults/${sourceId}/merge`, {
      target_fault_id: targetId,
    });
  }

  // -----------------------------------------------------------------------
  // Fault sub-resources
  // -----------------------------------------------------------------------

  /** Get individual error occurrences (notices) for a fault. */
  async getFaultNotices(
    id: number,
    limit?: number,
    offset?: number,
  ): Promise<NoticesResponse> {
    const params = new URLSearchParams();
    if (limit !== undefined) params.set('limit', String(limit));
    if (offset !== undefined) params.set('offset', String(offset));

    const qs = params.toString();
    return this.request<NoticesResponse>(
      'GET',
      `/api/v1/faults/${id}/notices${qs ? `?${qs}` : ''}`,
    );
  }

  /** Get occurrence statistics for a fault. */
  async getFaultStats(id: number): Promise<Record<string, unknown>> {
    return this.request<Record<string, unknown>>('GET', `/api/v1/faults/${id}/stats`);
  }

  /** Get comments on a fault. */
  async getFaultComments(id: number): Promise<CommentsResponse> {
    return this.request<CommentsResponse>('GET', `/api/v1/faults/${id}/comments`);
  }

  /** Create a comment on a fault. */
  async createFaultComment(
    id: number,
    comment: string,
    userId: number,
  ): Promise<Comment> {
    return this.request<Comment>('POST', `/api/v1/faults/${id}/comments`, {
      comment,
      user_id: userId,
    });
  }

  /** Get the audit-trail history for a fault. */
  async getFaultHistory(id: number): Promise<HistoryResponse> {
    return this.request<HistoryResponse>('GET', `/api/v1/faults/${id}/history`);
  }

  // -----------------------------------------------------------------------
  // Users
  // -----------------------------------------------------------------------

  /** Get all users. */
  async getUsers(): Promise<UsersResponse> {
    return this.request<UsersResponse>('GET', '/api/v1/users');
  }

  // -----------------------------------------------------------------------
  // Internal helpers
  // -----------------------------------------------------------------------

  /**
   * Centralised fetch wrapper that handles auth headers and error responses.
   */
  private async request<T>(
    method: string,
    path: string,
    body?: unknown,
  ): Promise<T> {
    const url = `${this.config.apiUrl}${path}`;

    const headers: Record<string, string> = {
      'X-API-Key': this.config.apiKey,
    };

    const init: RequestInit = { method, headers };

    if (body !== undefined) {
      headers['Content-Type'] = 'application/json';
      init.body = JSON.stringify(body);
    }

    try {
      const response = await fetch(url, init);

      if (!response.ok) {
        const errorData = (await response.json().catch(() => ({}))) as {
          error?: string;
          details?: string;
        };
        const msg = errorData.error ?? errorData.details ?? response.statusText;
        throw new Error(`${method} ${path} failed: ${response.status} - ${msg}`);
      }

      return (await response.json()) as T;
    } catch (error) {
      const err = error instanceof Error ? error : new Error(String(error));
      this.config.onError?.(err);
      throw err;
    }
  }

  /**
   * Parse a JS Error stack string into BacktraceFrame[].
   *
   * Handles the common V8 / SpiderMonkey / JavaScriptCore formats:
   *   - "    at functionName (file:line:col)"
   *   - "    at file:line:col"
   *   - "functionName@file:line:col"
   */
  private parseStack(stack: string): BacktraceFrame[] {
    if (!stack) return [];

    const frames: BacktraceFrame[] = [];

    for (const raw of stack.split('\n')) {
      const line = raw.trim();

      // V8-style: "at functionName (file:line:col)" or "at file:line:col"
      const v8 = line.match(/^at\s+(?:(.+?)\s+\()?(.+?):(\d+)(?::(\d+))?\)?$/);
      if (v8) {
        frames.push({
          file: v8[2],
          line: parseInt(v8[3], 10),
          function: v8[1] ?? '',
        });
        continue;
      }

      // SpiderMonkey / JSC: "functionName@file:line:col"
      const sm = line.match(/^(.+?)@(.+?):(\d+)(?::(\d+))?$/);
      if (sm) {
        frames.push({
          file: sm[2],
          line: parseInt(sm[3], 10),
          function: sm[1],
        });
        continue;
      }
    }

    return frames;
  }
}

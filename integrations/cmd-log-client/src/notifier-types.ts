// ---------------------------------------------------------------------------
// Shared / primitive types
// ---------------------------------------------------------------------------

/** A single stack frame in a backtrace */
export interface BacktraceFrame {
  file: string;
  line?: number;
  function?: string;
  code?: string;
  context?: string;
  vars?: Record<string, unknown>;
}

/** A breadcrumb event in the trail leading up to an error */
export interface Breadcrumb {
  category: string;
  message: string;
  metadata?: Record<string, unknown>;
  time: string; // ISO 8601
}

// ---------------------------------------------------------------------------
// Notice (error occurrence) types
// ---------------------------------------------------------------------------

/** Honeybadger-compatible notice request sent to POST /api/v1/notices */
export interface NoticeRequest {
  notifier: {
    name: string;
    version: string;
    url: string;
  };
  error: {
    class: string;
    message: string;
    backtrace: BacktraceFrame[];
  };
  request?: {
    url?: string;
    component?: string;
    action?: string;
    params?: Record<string, unknown>;
    session?: Record<string, unknown>;
    cookies?: Record<string, unknown>;
    context?: Record<string, unknown>;
  };
  server?: {
    environment_name?: string;
    hostname?: string;
    project_root?: string;
    revision?: string;
    data?: Record<string, unknown>;
  };
  breadcrumbs?: {
    enabled?: boolean;
    trail?: Breadcrumb[];
  };
}

/** Response from POST /api/v1/notices */
export interface NoticeResponse {
  id: string;
  fault_id: number;
}

// ---------------------------------------------------------------------------
// Fault types
// ---------------------------------------------------------------------------

/** A user account (returned inline on faults/comments/history) */
export interface User {
  id: number;
  email: string;
  name: string;
  avatar_url?: string;
  is_admin: boolean;
  created_at: string;
}

/** An error group (fault) */
export interface Fault {
  id: number;
  project_id?: number;
  error_class: string;
  message: string;
  location?: string;
  environment: string;
  resolved: boolean;
  ignored: boolean;
  assignee_id?: number;
  assignee?: User;
  tags: string[];
  public: boolean;
  occurrence_count: number;
  first_seen_at: string;
  last_seen_at: string;
  created_at: string;
  updated_at: string;
}

/** An individual error occurrence */
export interface Notice {
  id: string;
  fault_id: number;
  project_id?: number;
  message: string;
  backtrace?: BacktraceFrame[];
  context?: Record<string, unknown>;
  params?: Record<string, unknown>;
  session?: Record<string, unknown>;
  cookies?: Record<string, unknown>;
  environment?: Record<string, unknown>;
  breadcrumbs?: Breadcrumb[];
  revision?: string;
  hostname?: string;
  created_at: string;
}

/** A comment on a fault */
export interface Comment {
  id: number;
  fault_id: number;
  user_id: number;
  user?: User;
  comment: string;
  created_at: string;
}

/** An audit-trail entry for fault changes */
export interface FaultHistory {
  id: number;
  fault_id: number;
  action: string;
  user_id?: number;
  user?: User;
  revision?: string;
  created_at: string;
}

// ---------------------------------------------------------------------------
// API response wrappers
// ---------------------------------------------------------------------------

export interface FaultListResponse {
  faults: Fault[];
  total: number;
  limit: number;
  offset: number;
}

export interface NoticesResponse {
  notices: Notice[];
  limit: number;
  offset: number;
}

export interface CommentsResponse {
  comments: Comment[];
}

export interface HistoryResponse {
  history: FaultHistory[];
}

export interface UsersResponse {
  users: User[];
}

export interface MessageResponse {
  message: string;
}

// ---------------------------------------------------------------------------
// Client configuration
// ---------------------------------------------------------------------------

/** Configuration for the NotifierClient */
export interface NotifierClientConfig {
  /** Base URL of the cmd-log service (e.g. "https://logs.example.com") */
  apiUrl: string;
  /** API key for authentication */
  apiKey: string;
  /** Notifier metadata sent with every notice (optional override) */
  notifier?: {
    name: string;
    version: string;
    url: string;
  };
  /** Default server context merged into every notice */
  defaultServer?: {
    environment_name?: string;
    hostname?: string;
    project_root?: string;
    revision?: string;
    data?: Record<string, unknown>;
  };
  /** Default request context merged into every notice */
  defaultContext?: Record<string, unknown>;
  /** Error callback (default: console.error) */
  onError?: (error: Error) => void;
}

/** Options passed to the high-level `notify()` method */
export interface NotifyOptions {
  /** Override the error class (default: error.name or "Error") */
  errorClass?: string;
  /** Additional request context for this notice */
  request?: NoticeRequest['request'];
  /** Additional server context for this notice */
  server?: NoticeRequest['server'];
  /** Breadcrumb trail for this notice */
  breadcrumbs?: NoticeRequest['breadcrumbs'];
  /** Extra context merged into request.context */
  context?: Record<string, unknown>;
}

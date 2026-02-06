# Next.js Integration Guide — @cmdquery/log-ingestion-next

Use this guide to add structured logging and error tracking to a Next.js (13+ App Router) project using the [`@cmdquery/log-ingestion-next`](https://www.npmjs.com/package/@cmdquery/log-ingestion-next) npm package.

---

## 1. Install

```bash
npm install @cmdquery/log-ingestion-next
```

## 2. Environment Variables

Add to `.env.local` (never commit this file):

```env
# Server-side only (API routes, server actions, middleware)
CMD_LOG_URL=https://cmdlog.tech
CMD_LOG_API_KEY=your-api-key
CMD_LOG_SERVICE=my-nextjs-app

# Client-side (exposed to browser — use a separate, restricted key if possible)
NEXT_PUBLIC_CMD_LOG_URL=https://cmdlog.tech
NEXT_PUBLIC_CMD_LOG_API_KEY=your-client-api-key
```

## 3. Create Shared Instances

### `lib/logging/server.ts` — server-side singleton

```typescript
import 'server-only';
import { LogClient, NotifierClient } from '@cmdquery/log-ingestion-next';

export const logger = new LogClient({
  apiUrl: process.env.CMD_LOG_URL!,
  apiKey: process.env.CMD_LOG_API_KEY!,
  service: process.env.CMD_LOG_SERVICE ?? 'nextjs-app',
  enableBatching: false, // server requests are short-lived; send immediately
});

export const notifier = new NotifierClient({
  apiUrl: process.env.CMD_LOG_URL!,
  apiKey: process.env.CMD_LOG_API_KEY!,
  defaultServer: {
    environment_name: process.env.NODE_ENV,
    revision: process.env.VERCEL_GIT_COMMIT_SHA ?? 'unknown',
  },
});
```

### `lib/logging/client.ts` — browser singleton

```typescript
'use client';

import { LogClient, NotifierClient } from '@cmdquery/log-ingestion-next';

function createLogger() {
  const url = process.env.NEXT_PUBLIC_CMD_LOG_URL;
  const key = process.env.NEXT_PUBLIC_CMD_LOG_API_KEY;
  if (!url || !key) return null;

  return new LogClient({
    apiUrl: url,
    apiKey: key,
    service: 'nextjs-app',
    enableBatching: true,
    batchSize: 10,
    batchInterval: 5000,
  });
}

function createNotifier() {
  const url = process.env.NEXT_PUBLIC_CMD_LOG_URL;
  const key = process.env.NEXT_PUBLIC_CMD_LOG_API_KEY;
  if (!url || !key) return null;

  return new NotifierClient({
    apiUrl: url,
    apiKey: key,
    defaultServer: {
      environment_name: process.env.NODE_ENV,
    },
  });
}

export const logger = createLogger();
export const notifier = createNotifier();
```

---

## 4. Server-Side Usage

### API Route

```typescript
// app/api/users/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { logger, notifier } from '@/lib/logging/server';

export async function GET(req: NextRequest) {
  try {
    await logger.info('Fetching users', { path: '/api/users' });

    const users = await db.user.findMany();

    await logger.info('Users fetched', { count: users.length });
    return NextResponse.json({ users });
  } catch (err) {
    await notifier.notify(err as Error, {
      request: { url: '/api/users', component: 'UsersRoute', action: 'GET' },
    });
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
```

### Server Action

```typescript
// app/actions/create-post.ts
'use server';

import { logger, notifier } from '@/lib/logging/server';

export async function createPost(formData: FormData) {
  const title = formData.get('title') as string;

  try {
    await logger.info('Creating post', { title });
    const post = await db.post.create({ data: { title } });
    await logger.info('Post created', { postId: post.id });
    return { success: true, post };
  } catch (err) {
    await notifier.notify(err as Error, {
      context: { title },
      request: { component: 'createPost' },
    });
    return { success: false, error: 'Failed to create post' };
  }
}
```

### Middleware

```typescript
// middleware.ts
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';
import { logger } from '@/lib/logging/server';

export async function middleware(request: NextRequest) {
  const start = Date.now();
  const response = NextResponse.next();

  // fire-and-forget — don't block the response
  logger.info('Request', {
    method: request.method,
    path: request.nextUrl.pathname,
    ip: request.headers.get('x-forwarded-for'),
    ua: request.headers.get('user-agent'),
    durationMs: Date.now() - start,
  });

  return response;
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico).*)'],
};
```

---

## 5. Client-Side Usage

### In a Component

```typescript
'use client';

import { useEffect } from 'react';
import { logger } from '@/lib/logging/client';

export default function Dashboard() {
  useEffect(() => {
    logger?.info('Dashboard viewed');
  }, []);

  const handleClick = () => {
    logger?.info('CTA clicked', { button: 'upgrade' });
  };

  return <button onClick={handleClick}>Upgrade</button>;
}
```

### Global Error Handler (Client)

Add to your root layout to catch unhandled errors and promise rejections:

```typescript
// components/GlobalErrorReporter.tsx
'use client';

import { useEffect } from 'react';
import { notifier } from '@/lib/logging/client';

export function GlobalErrorReporter() {
  useEffect(() => {
    const handleError = (event: ErrorEvent) => {
      notifier?.notify(event.error ?? event.message, {
        context: { source: 'window.onerror' },
      });
    };

    const handleRejection = (event: PromiseRejectionEvent) => {
      const err = event.reason instanceof Error
        ? event.reason
        : new Error(String(event.reason));
      notifier?.notify(err, {
        context: { source: 'unhandledrejection' },
      });
    };

    window.addEventListener('error', handleError);
    window.addEventListener('unhandledrejection', handleRejection);
    return () => {
      window.removeEventListener('error', handleError);
      window.removeEventListener('unhandledrejection', handleRejection);
    };
  }, []);

  return null;
}
```

Then in `app/layout.tsx`:

```tsx
import { GlobalErrorReporter } from '@/components/GlobalErrorReporter';

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <GlobalErrorReporter />
        {children}
      </body>
    </html>
  );
}
```

### Next.js Error Boundary (`error.tsx`)

```typescript
// app/error.tsx
'use client';

import { useEffect } from 'react';
import { notifier } from '@/lib/logging/client';

export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    notifier?.notify(error, {
      context: { digest: error.digest, source: 'error.tsx' },
    });
  }, [error]);

  return (
    <div>
      <h2>Something went wrong</h2>
      <button onClick={reset}>Try again</button>
    </div>
  );
}
```

---

## 6. Fault Management (Optional)

The `NotifierClient` also provides a full fault management API you can use in admin dashboards or internal tools:

```typescript
import { notifier } from '@/lib/logging/server';

// List recent faults
const { faults, total } = await notifier.listFaults(undefined, 20, 0);

// Resolve / ignore / assign
await notifier.resolveFault(42);
await notifier.ignoreFault(42);
await notifier.assignFault(42, userId);

// Tags
await notifier.addFaultTags(42, ['payments', 'critical']);

// Merge duplicates
await notifier.mergeFaults(duplicateId, canonicalId);
```

---

## Summary

| File | Purpose |
| --- | --- |
| `lib/logging/server.ts` | Server-side `LogClient` + `NotifierClient` singletons |
| `lib/logging/client.ts` | Browser-side `LogClient` + `NotifierClient` singletons |
| `components/GlobalErrorReporter.tsx` | Catches unhandled client errors and reports them |
| `app/error.tsx` | Next.js error boundary that reports to cmd-log |
| `middleware.ts` | Logs every incoming request |

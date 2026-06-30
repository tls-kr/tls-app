// Thin wrappers over /api/* for arrange/assert steps that don't need
// a browser (e.g. seeding state, checking persistence from the backend
// side of a UI action). Authentication uses the APIRequestContext from
// the authedContext fixture — cookies set by POST /login flow through.
//
// Kept intentionally small; grow as specs need it.

import type { APIRequestContext } from '@playwright/test';

export async function apiGet<T = unknown>(
    req: APIRequestContext,
    path: string
): Promise<T> {
    const res = await req.get(`/exist/apps/tls-app/api${path}`);
    if (!res.ok()) {
        throw new Error(`GET api${path} -> ${res.status()}: ${await res.text()}`);
    }
    return res.json() as Promise<T>;
}

export async function apiPost<T = unknown>(
    req: APIRequestContext,
    path: string,
    body: unknown
): Promise<T> {
    const res = await req.post(`/exist/apps/tls-app/api${path}`, {
        data: body,
        headers: { 'Content-Type': 'application/json' },
    });
    if (!res.ok()) {
        throw new Error(`POST api${path} -> ${res.status()}: ${await res.text()}`);
    }
    return res.json() as Promise<T>;
}

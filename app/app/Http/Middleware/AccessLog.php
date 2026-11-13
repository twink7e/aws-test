<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Symfony\Component\HttpFoundation\Response;
use Throwable;

class AccessLog
{
    public function handle(Request $request, Closure $next): Response
    {
        $started = hrtime(true);

        try {
            $response = $next($request);
        } catch (Throwable $exception) {
            $this->write($request, 500, $started);

            throw $exception;
        }

        $this->write($request, $response->getStatusCode(), $started);

        return $response;
    }

    private function write(Request $request, int $status, int $started): void
    {
        Log::channel('access')->info('http_request', [
            'method' => $request->method(),
            'path' => $request->path(),
            'status' => $status,
            'duration_ms' => round((hrtime(true) - $started) / 1_000_000, 2),
            'trace_id' => $request->header('X-Amzn-Trace-Id'),
        ]);
    }
}

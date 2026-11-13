<?php

namespace App\Support;

use Illuminate\Support\Facades\Http;
use Throwable;

class AppConfig
{
    public function homepageMessage(): ?string
    {
        $url = config('demo.appconfig_url');

        if (! is_string($url) || $url === '') {
            return null;
        }

        try {
            $response = Http::acceptJson()->connectTimeout(0.3)->timeout(1)->get($url);
            $message = $response->successful() ? $response->json('homepage_message') : null;

            return is_string($message) ? $message : null;
        } catch (Throwable) {
            // The local agent may be starting or refreshing. The page stays available.
            return null;
        }
    }
}

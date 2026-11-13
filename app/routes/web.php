<?php

use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Log;
use App\Support\AppConfig;

Route::get('/', function (AppConfig $appConfig) {
    return view('home', [
        'environmentMessage' => config('demo.message'),
        'appConfigMessage' => $appConfig->homepageMessage(),
    ]);
});

Route::get('/healthz', fn () => response()->json(['status' => 'ok']));

if (config('demo.enable_failure_routes')) {
    Route::get('/__test/error', function () {
        Log::error('Intentional demo error for CloudWatch alarm testing');

        return response()->json(['logged' => true]);
    });

    Route::get('/__test/500', function () {
        abort(500, 'Intentional demo failure');
    });
}

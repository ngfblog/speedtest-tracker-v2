<?php

namespace Tests\Unit\Controllers\IntegrationsController;

use App;
use App\Http\Controllers\IntegrationsController;
use Henrywhitaker3\Healthchecks\Healthchecks;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class HealthcheckTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Controller
     *
     * @var IntegrationsController
     */
    private $controller;

    private $uuid;

    public function setUp() : void
    {
        parent::setUp();

        $this->controller = new IntegrationsController();
        $this->uuid = '123e4567-e89b-12d3-a456-426614174000';

        App::bind('healthcheck', function() {
            return new Healthchecks($this->uuid);
        });
    }

    public function testStartPing()
    {
        Http::fake([
            '*' => Http::response('', 200),
        ]);

        $resp = $this->controller->testHealthchecks('start')->original;

        $this->assertEquals([
            'method' => 'test healthchecks \'start\' endpoint',
            'success' => true
        ], $resp);
    }

    public function testSuccessPing()
    {
        Http::fake([
            '*' => Http::response('', 200),
        ]);

        $resp = $this->controller->testHealthchecks('success')->original;

        $this->assertEquals([
            'method' => 'test healthchecks \'success\' endpoint',
            'success' => true
        ], $resp);
    }

    public function testFailPing()
    {
        Http::fake([
            '*' => Http::response('', 200),
        ]);

        $resp = $this->controller->testHealthchecks('fail')->original;

        $this->assertEquals([
            'method' => 'test healthchecks \'fail\' endpoint',
            'success' => true
        ], $resp);
    }

    public function testInvalidUUID()
    {
        App::bind('healthcheck', function() {
            return new Healthchecks('invalid-uuid');
        });

        $resp = $this->controller->testHealthchecks('start')->original;

        $this->assertEquals([
            'method' => 'test healthchecks \'start\' endpoint',
            'success' => false,
            'error' => 'Invalid UUID'
        ], $resp);
    }
}

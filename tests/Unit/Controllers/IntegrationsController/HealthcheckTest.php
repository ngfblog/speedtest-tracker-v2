<?php

namespace Tests\Unit\Controllers\IntegrationsController;

use App;
use App\Helpers\SettingsHelper;
use App\Http\Controllers\IntegrationsController;
use Henrywhitaker3\Healthchecks\Healthchecks;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use Mockery;

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
        $this->bindMockFacade($this->uuid, true);
    }

    public function testStartPing()
    {
        $resp = $this->controller->testHealthchecks('start')->original;

        $this->assertEquals([
            'method' => 'test healthchecks \'start\' endpoint',
            'success' => true
        ], $resp);
    }

    public function testSuccessPing()
    {
        $resp = $this->controller->testHealthchecks('success')->original;

        $this->assertEquals([
            'method' => 'test healthchecks \'success\' endpoint',
            'success' => true
        ], $resp);
    }

    public function testFailPing()
    {
        $resp = $this->controller->testHealthchecks('fail')->original;

        $this->assertEquals([
            'method' => 'test healthchecks \'fail\' endpoint',
            'success' => true
        ], $resp);
    }

    public function testInvalidUUID()
    {
        $this->bindMockFacade('test', false);

        $resp = $this->controller->testHealthchecks('start')->original;

        $this->assertEquals([
            'method' => 'test healthchecks \'start\' endpoint',
            'success' => false,
            'error' => 'Invalid UUID'
        ], $resp);

        $this->bindMockFacade($this->uuid, true);
    }

    private function bindMockFacade(string $uuid, bool $isValid)
    {
        $mock = Mockery::mock(Healthchecks::class, [$uuid])->makePartial();
        
        if ($isValid) {
            $mock->shouldReceive('start')->andReturnSelf();
            $mock->shouldReceive('success')->andReturnSelf();
            $mock->shouldReceive('fail')->andReturnSelf();
            $mock->shouldReceive('ping')->andReturn(true);
        } else {
            // Simulate invalid UUID behavior or exception if needed
        }

        App::bind('healthcheck', function() use ($mock) {
            return $mock;
        });
    }
}

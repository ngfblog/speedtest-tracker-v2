<?php

namespace NgfBlog\Healthchecks\Tests;

use NgfBlog\Healthchecks\Exceptions\HealthchecksFailureException;
use NgfBlog\Healthchecks\Exceptions\HealthchecksUnauthorisedException;
use NgfBlog\Healthchecks\HealthchecksManager;

class IntegrationsTest extends Test
{
    /**
     * Auth HM instance
     *
     * @var HealthcheckManager
     */
    private $hmAuth;

    /**
     * Unauth HM instance
     *
     * @var HealthcheckManager
     */
    private $hmUnauth;

    /**
     * Uuid of created check
     *
     * @var [type]
     */
    private $uuid;

    public function setUp(): void
    {
        parent::setUp();

        $this->hmAuth = new HealthchecksManager($_ENV['APIKEY']);
        $this->hmUnauth = new HealthchecksManager('abc');
        $this->uuid = substr($this->hmAuth->createCheck()['ping_url'], 20);
    }

    public function tearDown(): void
    {
        $this->hmAuth->deleteCheck($this->uuid);
    }

    /**
     * Tests getting integrations endpoint
     *
     * @return void
     */
    public function testGetIntegrations()
    {
        $ints = $this->hmAuth->integrations();

        $this->assertIsArray($ints);
        $this->assertArrayHasKey('channels', $ints);
        $this->assertIsArray($ints['channels']);
    }

    /**
     * Tests getting integrations endpoint
     *
     * @return void
     */
    public function testGetIntegrationsUnauth()
    {
        try {
            $this->hmUnauth->integrations();
        } catch(HealthchecksUnauthorisedException $e) {
            $this->assertTrue(true);
            return true;
        }

        $this->assertTrue(false);
    }

    /**
     * Tests getting integrations endpoint
     *
     * @return void
     */
    public function testGetIntegrations404()
    {
        try {
            $hm = new HealthchecksManager('abc', 'https://github.com/ngfblog/404');
            $hm->integrations();
        } catch(HealthchecksFailureException $e) {
            $this->assertTrue(true);
            return true;
        }

        $this->assertTrue(false);
    }
}

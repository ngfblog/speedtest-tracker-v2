<?php

namespace NgfBlog\Healthchecks\Tests;

use NgfBlog\Healthchecks\Exceptions\HealthchecksUnauthorisedException;
use NgfBlog\Healthchecks\HealthchecksManager;

class ListChecksTest extends Test
{
    /**
     * Tests listing checks form API
     *
     * @return void
     */
    public function testListChecks()
    {
        $hc = new HealthchecksManager($_ENV['APIKEY']);

        $checks = $hc->listChecks();

        $this->assertIsArray($checks);
    }

    /**
     * Tests listing checks form API
     *
     * @return void
     */
    public function testListChecksUnauth()
    {
        $hc = new HealthchecksManager('abc');

        try {
            $hc->listChecks();
        } catch(HealthchecksUnauthorisedException $e) {
            $this->assertTrue(true);
            return true;
        }

        $this->assertTrue(false);
    }
}
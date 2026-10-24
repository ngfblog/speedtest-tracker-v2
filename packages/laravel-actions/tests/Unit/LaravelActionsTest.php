<?php

namespace NgfBlog\LaravelActions\Tests\Unit;

use NgfBlog\LaravelActions\Tests\Utils\ExampleInstantiatedAction;
use NgfBlog\LaravelActions\Tests\Utils\ExampleMultiArgumentAction;
use NgfBlog\LaravelActions\Tests\Utils\ExampleNoArgumentAction;
use NgfBlog\LaravelActions\Tests\Utils\ExampleNonInstantiatedAction;

class ActionTest extends \Orchestra\Testbench\TestCase
{
    protected function getPackageProviders($app)
    {
        return ['NgfBlog\LaravelActions\LaravelActionsServiceProvider'];
    }

    /**
     * Run an action when it's already been instantiated.
     *
     * @test
     * @return void
     */
    public function runInstantiatedAction()
    {
        $text = 'instantiated text';

        $action = new ExampleInstantiatedAction($text);
        $output = run($action);

        $this->assertEquals($text, $output);
    }

    /**
     * Run an action when it's not been instantiated.
     *
     * @test
     * @return void
     */
    public function runNonInstantiatedAction()
    {
        $text = 'non-instantiated text';

        $output = run(ExampleNonInstantiatedAction::class, $text);

        $this->assertEquals($text, $output);
    }

    /**
     * Run a multi-argaction when it's not been
     * instantiated.
     *
     * @test
     * @return void
     */
    public function runMultiArgumentAction()
    {
        $text = 'multi-argument ';
        $text2 = 'text';

        $output = run(ExampleMultiArgumentAction::class, $text, $text2);

        $this->assertEquals($text.$text2, $output);
    }

    /**
     * Run an action with no args when it's already
     * been instantiated.
     *
     * @test
     * @return void
     */
    public function runInstantiatedNoArgumentsAction()
    {
        $output = run(ExampleNoArgumentAction::class);

        $this->assertEquals('Hello', $output);
    }
}

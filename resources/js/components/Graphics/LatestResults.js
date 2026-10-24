import React, { Component } from 'react';
import ReactDOM from 'react-dom';
import Axios from 'axios';
import { Spinner, Container, Row, Col, Button } from 'react-bootstrap';
import { toast } from 'react-toastify';

// One decimal, or "-" when the value is missing (e.g. no successful tests yet)
const format = (stats, key) => {
    const value = stats ? parseFloat(stats[key]) : NaN;
    return Number.isFinite(value) ? value.toFixed(1) : '-';
};

export default class LatestResults extends Component {
    constructor(props) {
        super(props);

        this.state = {
            data: props.data,
            loading: true,
        }
    }

    componentDidMount = () => {
    }

    componentDidUpdate() {
        if(this.state.data != this.props.data) {
            this.setState({
                data: this.props.data,
                loading: false,
            });
        }
    }

    newScan = () => {
        var url = 'api/speedtest/run';
        Axios.get(url)
        .then((resp) => {
            toast.info('A test has been queued. This page will refresh when the test has finished.');
        })
        .catch((error) => {
            toast.error('There was an error queuing the speedtest.');
        });
    }

    render() {
        var loading = this.state.loading;
        var data = this.state.data;

        if(loading) {
            return (
                <div>
                    <Spinner animation="grow" />
                </div>
            )
        } else {
            if(data !== null) {
                return (
                    <Container className="mb-4" fluid>
                        <Row>
                            <Col lg={{ span: 4 }} md={{ span: 4 }} sm={{ span: 12 }} xs={{ span: 12 }}>
                                <div className="stat-card shadow-sm">
                                    <div className="stat-header">
                                        <i className="ti-signal stat-icon green"></i>
                                        <h5 className="stat-title">Ping</h5>
                                    </div>
                                    <div className="stat-body">
                                        <h1 className="stat-value">{format(data.data, 'ping')}</h1>
                                        <p className="stat-unit">ms (current)</p>
                                        <p className="stat-subtext">{format(data.average, 'ping')} ms (average)</p>
                                        <p className="stat-subtext">{format(data.maximum, 'ping')} ms (maximum)</p>
                                        <p className="stat-subtext">{format(data.minimum, 'ping')} ms (minimum)</p>
                                    </div>
                                </div>
                            </Col>
                            <Col lg={{ span: 4 }} md={{ span: 4 }} sm={{ span: 12 }} xs={{ span: 12 }}>
                                <div className="stat-card shadow-sm">
                                    <div className="stat-header">
                                        <i className="ti-download stat-icon orange"></i>
                                        <h5 className="stat-title">Download</h5>
                                    </div>
                                    <div className="stat-body">
                                        <h1 className="stat-value">{format(data.data, 'download')}</h1>
                                        <p className="stat-unit">Mbit/s (current)</p>
                                        <p className="stat-subtext">{format(data.average, 'download')} Mbit/s (average)</p>
                                        <p className="stat-subtext">{format(data.maximum, 'download')} Mbit/s (maximum)</p>
                                        <p className="stat-subtext">{format(data.minimum, 'download')} Mbit/s (minimum)</p>
                                    </div>
                                </div>
                            </Col>
                            <Col lg={{ span: 4 }} md={{ span: 4 }} sm={{ span: 12 }} xs={{ span: 12 }}>
                                <div className="stat-card shadow-sm">
                                    <div className="stat-header">
                                        <i className="ti-upload stat-icon blue"></i>
                                        <h5 className="stat-title">Upload</h5>
                                    </div>
                                    <div className="stat-body">
                                        <h1 className="stat-value">{format(data.data, 'upload')}</h1>
                                        <p className="stat-unit">Mbit/s (current)</p>
                                        <p className="stat-subtext">{format(data.average, 'upload')} Mbit/s (average)</p>
                                        <p className="stat-subtext">{format(data.maximum, 'upload')} Mbit/s (maximum)</p>
                                        <p className="stat-subtext">{format(data.minimum, 'upload')} Mbit/s (minimum)</p>
                                    </div>
                                </div>
                            </Col>
                        </Row>
                        <Row>
                            <Col sm={{ span: 12 }}>
                                <div className="text-center mt-4">
                                    <Button className="d-inline-block mx-3 mb-2" variant="primary" onClick={this.newScan}>Test again</Button>
                                    <p className="text-muted mb-0 d-inline-block">Last test performed at: {new Date(data.data.created_at).toLocaleString()}</p>
                                </div>
                            </Col>
                        </Row>
                    </Container>
                )
            } else {
                return (
                    <Container className="mb-4" fluid>
                        <Row>
                            <Col sm={{ span: 12 }}>
                                <div className="text-center">
                                    <Button variant="primary" onClick={this.newScan}>Start your first test!</Button>
                                </div>
                            </Col>
                        </Row>
                    </Container>
                );
            }
        }
    }
}

if (document.getElementById('LatestResults')) {
    ReactDOM.render(<LatestResults />, document.getElementById('LatestResults'));
}

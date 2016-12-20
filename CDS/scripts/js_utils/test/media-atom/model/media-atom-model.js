const assert = require('assert');
const MediaAtomModel = require('../../../media-atom/model/media-atom-model');

describe('MediaAtomModel', () => {
    before(function (done) {
        this.badApiResponse = {
            channelId: 'ChannelOne',
            tags: ['mic', 'check', 'one', 'two']
        };

        this.goodApiResponse = {
            title: 'foo',
            channelId: 'ChannelOne',
            youtubeCategoryId: '1',
            posterImage: {
                assets: [{
                    mimeType: "image/jpeg",
                    file: "https://media.guim.co.uk/4d7c1db00237690e268015c5fd09502c66cdfd34/0_64_3488_1962/140.jpg",
                    dimensions: { height: 79, width: 140 },
                    size: 7324
                }, {
                    mimeType: "image/jpeg",
                    file: "https://media.guim.co.uk/4d7c1db00237690e268015c5fd09502c66cdfd34/0_64_3488_1962/2000.jpg",
                    dimensions: { height: 1125, width: 2000 },
                    size: 218024
                }, {
                    mimeType: "image/jpeg",
                    file: "https://media.guim.co.uk/4d7c1db00237690e268015c5fd09502c66cdfd34/0_64_3488_1962/500.jpg",
                    dimensions: { height: 281, width: 500 },
                    size: 32557
                }, {
                    mimeType: "image/jpeg",
                    file: "https://media.guim.co.uk/4d7c1db00237690e268015c5fd09502c66cdfd34/0_64_3488_1962/3488.jpg",
                    dimensions: { height: 1962, width: 3488 },
                    size: 460127
                }, {
                    mimeType: "image/jpeg",
                    file: "https://media.guim.co.uk/4d7c1db00237690e268015c5fd09502c66cdfd34/0_64_3488_1962/1000.jpg",
                    dimensions: { height: 563, width: 1000 },
                    size: 85022
                }]
            }
        };

        done();
    });

    it('should fail to validate when required fields are missing', function (done) {
        const model = new MediaAtomModel(this.badApiResponse);

        model.validate().then(e => console.log(e)).catch(actual => {
            const expected = ['title', 'youtubeCategoryId'];

            assert.deepEqual(actual, expected);
            done();
        });
    });

    it('should return the best poster image under 2MB', function (done) {
        const model = new MediaAtomModel(this.goodApiResponse);

        const actual = model.posterImage;
        const expected = 'https://media.guim.co.uk/4d7c1db00237690e268015c5fd09502c66cdfd34/0_64_3488_1962/3488.jpg';

        assert.equal(actual, expected);
        done();
    });
});
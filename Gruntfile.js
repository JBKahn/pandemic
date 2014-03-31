module.exports = function (grunt) {
    "use strict";
    grunt.initConfig({
        watch: {
            dev: {
                files: [
                    "coffee/*",
                ],
                tasks: ['default']
            }
        },

        coffee: {
            compile: {
                options: {
                    sourceMap: true
                },
                files: {
                    'game.js': 'coffee/game.coffee',
                }
            }
        },
    });

    grunt.loadNpmTasks('grunt-contrib-watch');
    grunt.loadNpmTasks('grunt-contrib-coffee');

    grunt.registerTask('default', ['coffee']);
    grunt.registerTask('dev', ['default', 'watch']);

};

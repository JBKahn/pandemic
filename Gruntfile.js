module.exports = function (grunt) {
    "use strict";
    grunt.initConfig({
        watch: {
            dev: {
                files: [
                    "*.js",
                ],
                tasks: ['default']
            }
        },

        // coffee: {
        //     compile: {
        //         files: {
        //             'game.js': 'coffee/game.coffee',
        //         }
        //     }
        // },
    });

    grunt.loadNpmTasks('grunt-contrib-watch');
    // grunt.loadNpmTasks('grunt-contrib-coffee');

    grunt.registerTask('default');
    grunt.registerTask('dev', ['default', 'watch']);

};

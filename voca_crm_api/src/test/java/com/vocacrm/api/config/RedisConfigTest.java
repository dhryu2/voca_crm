package com.vocacrm.api.config;

import org.junit.jupiter.api.Test;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.connection.lettuce.LettuceConnectionFactory;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.serializer.GenericJackson2JsonRedisSerializer;
import org.springframework.data.redis.serializer.StringRedisSerializer;
import org.springframework.test.util.ReflectionTestUtils;

import static org.assertj.core.api.Assertions.assertThat;

class RedisConfigTest {

    @Test
    void 비밀번호가있으면_연결설정에_비밀번호가반영된다() {
        RedisConfig config = new RedisConfig();
        ReflectionTestUtils.setField(config, "host", "localhost");
        ReflectionTestUtils.setField(config, "port", 6379);
        ReflectionTestUtils.setField(config, "password", "secret-pass");

        LettuceConnectionFactory factory = (LettuceConnectionFactory) config.redisConnectionFactory();

        assertThat(factory.getHostName()).isEqualTo("localhost");
        assertThat(factory.getPort()).isEqualTo(6379);
        assertThat(factory.getPassword()).isEqualTo("secret-pass");
    }

    @Test
    void 비밀번호가없으면_연결설정에_비밀번호를설정하지않는다() {
        RedisConfig config = new RedisConfig();
        ReflectionTestUtils.setField(config, "host", "localhost");
        ReflectionTestUtils.setField(config, "port", 6379);
        ReflectionTestUtils.setField(config, "password", "");

        LettuceConnectionFactory factory = (LettuceConnectionFactory) config.redisConnectionFactory();

        assertThat(factory.getPassword()).isNullOrEmpty();
    }

    @Test
    void redisTemplate은_문자열키와JSON값직렬화를사용한다() {
        RedisConfig config = new RedisConfig();
        RedisConnectionFactory connectionFactory = new LettuceConnectionFactory();

        RedisTemplate<String, Object> template = config.redisTemplate(connectionFactory);

        assertThat(template.getKeySerializer()).isInstanceOf(StringRedisSerializer.class);
        assertThat(template.getHashKeySerializer()).isInstanceOf(StringRedisSerializer.class);
        assertThat(template.getValueSerializer()).isInstanceOf(GenericJackson2JsonRedisSerializer.class);
        assertThat(template.getHashValueSerializer()).isInstanceOf(GenericJackson2JsonRedisSerializer.class);
        assertThat(template.getConnectionFactory()).isSameAs(connectionFactory);
    }
}

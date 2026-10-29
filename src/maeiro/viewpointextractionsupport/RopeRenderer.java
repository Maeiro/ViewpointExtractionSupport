package maeiro.viewpointextractionsupport;

import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.FloatBuffer;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

public final class RopeRenderer {
    private static final int GL_ARRAY_BUFFER = 0x8892;
    private static final int GL_ARRAY_BUFFER_BINDING = 0x8894;
    private static final int GL_BLEND = 0x0BE2;
    private static final int GL_BLEND_DST_ALPHA = 0x80CA;
    private static final int GL_BLEND_DST_RGB = 0x80C8;
    private static final int GL_BLEND_EQUATION_ALPHA = 0x883D;
    private static final int GL_BLEND_EQUATION_RGB = 0x8009;
    private static final int GL_BLEND_SRC_ALPHA = 0x80CB;
    private static final int GL_BLEND_SRC_RGB = 0x80C9;
    private static final int GL_CULL_FACE = 0x0B44;
    private static final int GL_CURRENT_PROGRAM = 0x8B8D;
    private static final int GL_DEPTH_FUNC = 0x0B74;
    private static final int GL_DEPTH_TEST = 0x0B71;
    private static final int GL_DEPTH_WRITEMASK = 0x0B72;
    private static final int GL_DRAW_FRAMEBUFFER = 0x8CA9;
    private static final int GL_DRAW_FRAMEBUFFER_BINDING = 0x8CA6;
    private static final int GL_DYNAMIC_DRAW = 0x88E8;
    private static final int GL_FLOAT = 0x1406;
    private static final int GL_FRAGMENT_SHADER = 0x8B30;
    private static final int GL_LEQUAL = 0x0203;
    private static final int GL_LINK_STATUS = 0x8B82;
    private static final int GL_READ_FRAMEBUFFER = 0x8CA8;
    private static final int GL_READ_FRAMEBUFFER_BINDING = 0x8CAA;
    private static final int GL_SCISSOR_TEST = 0x0C11;
    private static final int GL_SRC_ALPHA = 0x0302;
    private static final int GL_ONE = 1;
    private static final int GL_ONE_MINUS_SRC_ALPHA = 0x0303;
    private static final int GL_TRIANGLES = 0x0004;
    private static final int GL_VERTEX_ARRAY_BINDING = 0x85B5;
    private static final int GL_VERTEX_SHADER = 0x8B31;
    private static final int STRIDE = 7 * Float.BYTES;

    private static final String VERTEX_SHADER = """
            #version 330 core
            layout(location = 0) in vec3 position;
            layout(location = 1) in vec4 vertexColor;
            uniform mat4 viewProjection;
            out vec4 color;
            void main() {
                gl_Position = viewProjection * vec4(position, 1.0);
                color = vertexColor;
            }
            """;
    private static final String FRAGMENT_SHADER = """
            #version 330 core
            in vec4 color;
            out vec4 outputColor;
            void main() {
                outputColor = color;
            }
            """;

    private static final Map<Object, Snapshot> snapshots = new ConcurrentHashMap<>();
    private static volatile boolean failed;
    private static Field irisDrawn, rendererFrame, viewProjection, eyeX, eyeY, eyeZ;
    private static Method bindTarget, glGetInteger, glGetIntegerv, glGetBoolean, glIsEnabled;
    private static Method glUseProgram, glBindVertexArray, glBindBuffer, glBufferData;
    private static Method glEnableVertexAttribArray, glVertexAttribPointer, glDrawArrays;
    private static Method glEnable, glDisable, glDepthMask, glDepthFunc, glBlendFuncSeparate;
    private static Method glBlendEquationSeparate, glBindFramebuffer, glViewport;
    private static Method glUniformMatrix4fv;
    private static int program, vao, vbo, matrixUniform;
    private static FloatBuffer uploadBuffer;

    record Snapshot(float[] vertices) {
    }

    static final class MeshBuilder {
        private float[] values = new float[1024];
        private int size;

        void addSegment(float x1, float y1, float z1, float x2, float y2, float z2,
                float cameraX, float cameraY, float cameraZ, float alpha,
                boolean extendStart, boolean extendEnd) {
            ensureCapacity(9);
            values[size++] = cameraX - x1;
            values[size++] = z1 - cameraZ;
            values[size++] = cameraY - y1;
            values[size++] = cameraX - x2;
            values[size++] = z2 - cameraZ;
            values[size++] = cameraY - y2;
            values[size++] = alpha;
            values[size++] = extendStart ? 1 : 0;
            values[size++] = extendEnd ? 1 : 0;
        }

        float[] toArray() {
            float[] result = new float[size];
            System.arraycopy(values, 0, result, 0, size);
            return result;
        }

        private void ensureCapacity(int required) {
            if (size + required <= values.length) return;
            float[] expanded = new float[Math.max(values.length * 2, size + required)];
            System.arraycopy(values, 0, expanded, 0, size);
            values = expanded;
        }
    }

    private RopeRenderer() {
    }

    static void capture(Object scene, float[] vertices) {
        if (scene == null) return;
        if (vertices.length == 0) snapshots.remove(scene);
        else snapshots.put(scene, new Snapshot(vertices));
    }

    static void clear() {
        snapshots.clear();
    }

    static void clear(Object scene) {
        if (scene != null) snapshots.remove(scene);
    }

    public static void draw(Object scene) {
        Snapshot frame = scene == null ? null : snapshots.get(scene);
        if (failed || frame == null) return;
        try {
            if (glDrawArrays == null) initialize();
            if (irisDrawn.getBoolean(null)) return;

            Object context = rendererFrame.get(null);
            Object matrix = viewProjection.get(context);
            if (matrix == null) return;
            float[] matrixValues = new float[16];
            matrix.getClass().getMethod("get", float[].class).invoke(matrix, (Object) matrixValues);
            float cameraX = eyeX.getFloat(context);
            float cameraY = eyeY.getFloat(context);
            float cameraZ = eyeZ.getFloat(context);
            float[] expandedVertices = expand(frame.vertices, cameraX, cameraY, cameraZ);

            int oldProgram = integer(GL_CURRENT_PROGRAM);
            int oldVao = integer(GL_VERTEX_ARRAY_BINDING);
            int oldVbo = integer(GL_ARRAY_BUFFER_BINDING);
            int oldDrawFramebuffer = integer(GL_DRAW_FRAMEBUFFER_BINDING);
            int oldReadFramebuffer = integer(GL_READ_FRAMEBUFFER_BINDING);
            int[] oldViewport = new int[4];
            invoke(glGetIntegerv, GL_VIEWPORT, oldViewport);
            boolean oldBlend = enabled(GL_BLEND);
            boolean oldDepth = enabled(GL_DEPTH_TEST);
            boolean oldCull = enabled(GL_CULL_FACE);
            boolean oldScissor = enabled(GL_SCISSOR_TEST);
            boolean oldDepthMask = (boolean) invoke(glGetBoolean, GL_DEPTH_WRITEMASK);
            int oldDepthFunc = integer(GL_DEPTH_FUNC);
            int oldBlendSourceRgb = integer(GL_BLEND_SRC_RGB);
            int oldBlendDestinationRgb = integer(GL_BLEND_DST_RGB);
            int oldBlendSourceAlpha = integer(GL_BLEND_SRC_ALPHA);
            int oldBlendDestinationAlpha = integer(GL_BLEND_DST_ALPHA);
            int oldBlendEquationRgb = integer(GL_BLEND_EQUATION_RGB);
            int oldBlendEquationAlpha = integer(GL_BLEND_EQUATION_ALPHA);

            try {
                invoke(bindTarget);
                invoke(glUseProgram, program);
                invoke(glBindVertexArray, vao);
                invoke(glBindBuffer, GL_ARRAY_BUFFER, vbo);
                upload(expandedVertices);
                invoke(glUniformMatrix4fv, matrixUniform, false, matrixValues);
                invoke(glEnable, GL_DEPTH_TEST);
                invoke(glDepthFunc, GL_LEQUAL);
                invoke(glDepthMask, false);
                invoke(glEnable, GL_BLEND);
                invoke(glBlendEquationSeparate, 0x8006, 0x8006);
                invoke(glBlendFuncSeparate, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ONE);
                invoke(glDisable, GL_CULL_FACE);
                invoke(glDisable, GL_SCISSOR_TEST);
                invoke(glDrawArrays, GL_TRIANGLES, 0, expandedVertices.length / 7);
            } finally {
                invoke(glUseProgram, oldProgram);
                invoke(glBindVertexArray, oldVao);
                invoke(glBindBuffer, GL_ARRAY_BUFFER, oldVbo);
                invoke(glBlendEquationSeparate, oldBlendEquationRgb, oldBlendEquationAlpha);
                invoke(glBlendFuncSeparate, oldBlendSourceRgb, oldBlendDestinationRgb,
                        oldBlendSourceAlpha, oldBlendDestinationAlpha);
                toggle(GL_BLEND, oldBlend);
                invoke(glDepthFunc, oldDepthFunc);
                invoke(glDepthMask, oldDepthMask);
                toggle(GL_DEPTH_TEST, oldDepth);
                toggle(GL_CULL_FACE, oldCull);
                toggle(GL_SCISSOR_TEST, oldScissor);
                invoke(glBindFramebuffer, GL_DRAW_FRAMEBUFFER, oldDrawFramebuffer);
                invoke(glBindFramebuffer, GL_READ_FRAMEBUFFER, oldReadFramebuffer);
                invoke(glViewport, oldViewport[0], oldViewport[1], oldViewport[2], oldViewport[3]);
            }
        } catch (Throwable error) {
            failed = true;
            System.err.println("[Viewpoint Extraction Support] Opaque rope rendering unavailable: " + error);
        }
    }

    private static void initialize() throws ReflectiveOperationException {
        Class<?> renderer = Class.forName("viewpoint.render.WorldRenderer");
        Class<?> context = Class.forName("viewpoint.render.FrameContext");
        irisDrawn = renderer.getDeclaredField("irisDrawn");
        irisDrawn.setAccessible(true);
        rendererFrame = renderer.getDeclaredField("frame");
        rendererFrame.setAccessible(true);
        viewProjection = context.getField("viewProjection");
        eyeX = context.getField("eyeX");
        eyeY = context.getField("eyeY");
        eyeZ = context.getField("eyeZ");
        bindTarget = renderer.getMethod("bindTarget");

        Class<?> gl = Class.forName("org.lwjgl.opengl.GL33");
        glGetInteger = gl.getMethod("glGetInteger", int.class);
        glGetIntegerv = gl.getMethod("glGetIntegerv", int.class, int[].class);
        glGetBoolean = gl.getMethod("glGetBoolean", int.class);
        glIsEnabled = gl.getMethod("glIsEnabled", int.class);
        glUseProgram = gl.getMethod("glUseProgram", int.class);
        glBindVertexArray = gl.getMethod("glBindVertexArray", int.class);
        glBindBuffer = gl.getMethod("glBindBuffer", int.class, int.class);
        glBufferData = gl.getMethod("glBufferData", int.class, FloatBuffer.class, int.class);
        glEnableVertexAttribArray = gl.getMethod("glEnableVertexAttribArray", int.class);
        glVertexAttribPointer = gl.getMethod("glVertexAttribPointer", int.class, int.class,
                int.class, boolean.class, int.class, long.class);
        glDrawArrays = gl.getMethod("glDrawArrays", int.class, int.class, int.class);
        glEnable = gl.getMethod("glEnable", int.class);
        glDisable = gl.getMethod("glDisable", int.class);
        glDepthMask = gl.getMethod("glDepthMask", boolean.class);
        glDepthFunc = gl.getMethod("glDepthFunc", int.class);
        glBlendFuncSeparate = gl.getMethod("glBlendFuncSeparate", int.class, int.class, int.class, int.class);
        glBlendEquationSeparate = gl.getMethod("glBlendEquationSeparate", int.class, int.class);
        glBindFramebuffer = gl.getMethod("glBindFramebuffer", int.class, int.class);
        glViewport = gl.getMethod("glViewport", int.class, int.class, int.class, int.class);
        glUniformMatrix4fv = gl.getMethod("glUniformMatrix4fv", int.class, boolean.class, float[].class);

        program = createProgram(gl);
        matrixUniform = (int) invoke(gl.getMethod("glGetUniformLocation", int.class, CharSequence.class),
                program, "viewProjection");
        vao = (int) invoke(gl.getMethod("glGenVertexArrays"));
        vbo = (int) invoke(gl.getMethod("glGenBuffers"));
        int oldVao = integer(GL_VERTEX_ARRAY_BINDING);
        int oldBuffer = integer(GL_ARRAY_BUFFER_BINDING);
        invoke(glBindVertexArray, vao);
        invoke(glBindBuffer, GL_ARRAY_BUFFER, vbo);
        invoke(glEnableVertexAttribArray, 0);
        invoke(glVertexAttribPointer, 0, 3, GL_FLOAT, false, STRIDE, 0L);
        invoke(glEnableVertexAttribArray, 1);
        invoke(glVertexAttribPointer, 1, 4, GL_FLOAT, false, STRIDE, 3L * Float.BYTES);
        invoke(glBindVertexArray, oldVao);
        invoke(glBindBuffer, GL_ARRAY_BUFFER, oldBuffer);
    }

    private static int createProgram(Class<?> gl) throws ReflectiveOperationException {
        Method createShader = gl.getMethod("glCreateShader", int.class);
        Method shaderSource = gl.getMethod("glShaderSource", int.class, CharSequence.class);
        Method compileShader = gl.getMethod("glCompileShader", int.class);
        Method getShader = gl.getMethod("glGetShaderi", int.class, int.class);
        Method getShaderLog = gl.getMethod("glGetShaderInfoLog", int.class);
        Method deleteShader = gl.getMethod("glDeleteShader", int.class);
        Method createProgram = gl.getMethod("glCreateProgram");
        Method attachShader = gl.getMethod("glAttachShader", int.class, int.class);
        Method linkProgram = gl.getMethod("glLinkProgram", int.class);
        Method getProgram = gl.getMethod("glGetProgrami", int.class, int.class);
        Method getProgramLog = gl.getMethod("glGetProgramInfoLog", int.class);
        Method deleteProgram = gl.getMethod("glDeleteProgram", int.class);

        int vertex = compileShader(createShader, shaderSource, compileShader, getShader, getShaderLog,
                GL_VERTEX_SHADER, VERTEX_SHADER);
        int fragment = compileShader(createShader, shaderSource, compileShader, getShader, getShaderLog,
                GL_FRAGMENT_SHADER, FRAGMENT_SHADER);
        int result = (int) invoke(createProgram);
        invoke(attachShader, result, vertex);
        invoke(attachShader, result, fragment);
        invoke(linkProgram, result);
        invoke(deleteShader, vertex);
        invoke(deleteShader, fragment);
        if ((int) invoke(getProgram, result, GL_LINK_STATUS) == 0) {
            String message = (String) invoke(getProgramLog, result);
            invoke(deleteProgram, result);
            throw new IllegalStateException(message);
        }
        return result;
    }

    private static int compileShader(Method create, Method source, Method compile, Method getShader,
            Method getLog, int type, String text) throws ReflectiveOperationException {
        int shader = (int) invoke(create, type);
        invoke(source, shader, text);
        invoke(compile, shader);
        if ((int) invoke(getShader, shader, 0x8B81) == 0) {
            String message = (String) invoke(getLog, shader);
            throw new IllegalStateException(message);
        }
        return shader;
    }

    private static void upload(float[] vertices) throws ReflectiveOperationException {
        if (uploadBuffer == null || uploadBuffer.capacity() < vertices.length) {
            int capacity = 1;
            while (capacity < vertices.length) capacity <<= 1;
            uploadBuffer = ByteBuffer.allocateDirect(capacity * Float.BYTES)
                    .order(ByteOrder.nativeOrder()).asFloatBuffer();
        }
        uploadBuffer.clear();
        uploadBuffer.put(vertices);
        uploadBuffer.flip();
        invoke(glBufferData, GL_ARRAY_BUFFER, uploadBuffer, GL_DYNAMIC_DRAW);
    }

    private static float[] expand(float[] segments, float eyeX, float eyeY, float eyeZ) {
        int axialSteps = 3;
        int sides = 9;
        float[] vertices = new float[segments.length / 9 * axialSteps * sides * 6 * 7];
        int offset = 0;
        float phase = 0;
        for (int index = 0; index < segments.length; index += 9) {
            float ax = segments[index], ay = segments[index + 1], az = segments[index + 2];
            float bx = segments[index + 3], by = segments[index + 4], bz = segments[index + 5];
            float dx = bx - ax, dy = by - ay, dz = bz - az;
            float length = (float) Math.sqrt(dx * dx + dy * dy + dz * dz);
            if (length < 0.0001f) continue;
            dx /= length;
            dy /= length;
            dz /= length;

            float rx = Math.abs(dy) < 0.9f ? 0 : 1;
            float ry = Math.abs(dy) < 0.9f ? 1 : 0;
            float rz = 0;
            float projection = rx * dx + ry * dy + rz * dz;
            rx -= projection * dx;
            ry -= projection * dy;
            rz -= projection * dz;
            float basisLength = (float) Math.sqrt(rx * rx + ry * ry + rz * rz);
            rx /= basisLength;
            ry /= basisLength;
            rz /= basisLength;
            float sx = dy * rz - dz * ry;
            float sy = dz * rx - dx * rz;
            float sz = dx * ry - dy * rx;

            float extension = 0.035f;
            if (segments[index + 7] > 0.5f) {
                ax -= dx * extension;
                ay -= dy * extension;
                az -= dz * extension;
            }
            if (segments[index + 8] > 0.5f) {
                bx += dx * extension;
                by += dy * extension;
                bz += dz * extension;
            }

            float alpha = segments[index + 6];
            float segmentPhase = phase;
            for (int step = 0; step < axialSteps; step++) {
                float t0 = step / (float) axialSteps;
                float t1 = (step + 1) / (float) axialSteps;
                float p0 = segmentPhase + length * t0 * 28;
                float p1 = segmentPhase + length * t1 * 28;
                for (int side = 0; side < sides; side++) {
                    float a0 = side * (float) (Math.PI * 2 / sides);
                    float a1 = (side + 1) * (float) (Math.PI * 2 / sides);
                    offset = putRopeVertex(vertices, offset, ax, ay, az, bx, by, bz, t0, a0, p0,
                            rx, ry, rz, sx, sy, sz, alpha);
                    offset = putRopeVertex(vertices, offset, ax, ay, az, bx, by, bz, t0, a1, p0,
                            rx, ry, rz, sx, sy, sz, alpha);
                    offset = putRopeVertex(vertices, offset, ax, ay, az, bx, by, bz, t1, a0, p1,
                            rx, ry, rz, sx, sy, sz, alpha);
                    offset = putRopeVertex(vertices, offset, ax, ay, az, bx, by, bz, t1, a0, p1,
                            rx, ry, rz, sx, sy, sz, alpha);
                    offset = putRopeVertex(vertices, offset, ax, ay, az, bx, by, bz, t0, a1, p0,
                            rx, ry, rz, sx, sy, sz, alpha);
                    offset = putRopeVertex(vertices, offset, ax, ay, az, bx, by, bz, t1, a1, p1,
                            rx, ry, rz, sx, sy, sz, alpha);
                }
            }
            phase += length * 28;
        }
        if (offset == vertices.length) return vertices;
        float[] result = new float[offset];
        System.arraycopy(vertices, 0, result, 0, offset);
        return result;
    }

    private static int putRopeVertex(float[] vertices, int offset,
            float ax, float ay, float az, float bx, float by, float bz,
            float t, float angle, float phase,
            float rx, float ry, float rz, float sx, float sy, float sz, float alpha) {
        float weave = (float) Math.cos(3 * angle - phase);
        float radius = 0.036f * (1 + 0.13f * weave);
        float radialX = rx * (float) Math.cos(angle) + sx * (float) Math.sin(angle);
        float radialY = ry * (float) Math.cos(angle) + sy * (float) Math.sin(angle);
        float radialZ = rz * (float) Math.cos(angle) + sz * (float) Math.sin(angle);
        float light = 0.72f + 0.28f * Math.max(0, radialX * -0.35f + radialY * 0.8f + radialZ * -0.45f);
        float strandShade = weave > 0.25f ? 1.0f : 0.78f;
        return putVertex(vertices, offset,
                ax + (bx - ax) * t + radialX * radius,
                ay + (by - ay) * t + radialY * radius,
                az + (bz - az) * t + radialZ * radius,
                0.78f * light * strandShade, 0.62f * light * strandShade,
                0.39f * light * strandShade, alpha);
    }

    private static int putVertex(float[] vertices, int offset, float x, float y, float z,
            float red, float green, float blue, float alpha) {
        vertices[offset++] = x;
        vertices[offset++] = y;
        vertices[offset++] = z;
        vertices[offset++] = red;
        vertices[offset++] = green;
        vertices[offset++] = blue;
        vertices[offset++] = alpha;
        return offset;
    }

    private static int integer(int name) throws ReflectiveOperationException {
        return (int) invoke(glGetInteger, name);
    }

    private static boolean enabled(int name) throws ReflectiveOperationException {
        return (boolean) invoke(glIsEnabled, name);
    }

    private static void toggle(int name, boolean enabled) throws ReflectiveOperationException {
        invoke(enabled ? glEnable : glDisable, name);
    }

    private static Object invoke(Method method, Object... args) throws ReflectiveOperationException {
        return method.invoke(null, args);
    }

    private static final int GL_VIEWPORT = 0x0BA2;
}

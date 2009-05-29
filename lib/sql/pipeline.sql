--
-- PostgreSQL database dump
--

SET client_encoding = 'UTF8';
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA public IS 'Standard public schema';


SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: groups; Type: TABLE; Schema: public; Owner: pipeline; Tablespace: 
--

CREATE TABLE groups (
    group_id smallint NOT NULL,
    group_name character varying(32) NOT NULL,
    info character varying(255),
    created timestamp without time zone
);


ALTER TABLE public.groups OWNER TO pipeline;

--
-- Name: groups_group_id_seq; Type: SEQUENCE; Schema: public; Owner: pipeline
--

CREATE SEQUENCE groups_group_id_seq
    START WITH 1
    INCREMENT BY 1
    MAXVALUE 128
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.groups_group_id_seq OWNER TO pipeline;

--
-- Name: project; Type: TABLE; Schema: public; Owner: pipeline; Tablespace: 
--

CREATE TABLE project (
    project_id serial NOT NULL,
    user_id integer DEFAULT 0 NOT NULL,
    name character varying(255) DEFAULT ''::character varying NOT NULL,
    specie character varying(32),
    created timestamp without time zone NOT NULL
);


ALTER TABLE public.project OWNER TO pipeline;

--
-- Name: task; Type: TABLE; Schema: public; Owner: pipeline; Tablespace: 
--

CREATE TABLE task (
    task_id smallint NOT NULL,
    name character varying(16) DEFAULT ''::character varying NOT NULL,
    enabled boolean DEFAULT true NOT NULL
);


ALTER TABLE public.task OWNER TO pipeline;

--
-- Name: task_status; Type: TABLE; Schema: public; Owner: pipeline; Tablespace: 
--

CREATE TABLE task_status (
    status_id smallint DEFAULT 0 NOT NULL,
    name character varying(16)
);


ALTER TABLE public.task_status OWNER TO pipeline;

--
-- Name: user_groups; Type: TABLE; Schema: public; Owner: pipeline; Tablespace: 
--

CREATE TABLE user_groups (
    group_id smallint NOT NULL,
    user_id integer NOT NULL
);


ALTER TABLE public.user_groups OWNER TO pipeline;

--
-- Name: users; Type: TABLE; Schema: public; Owner: pipeline; Tablespace: 
--

CREATE TABLE users (
    user_id serial NOT NULL,
    username character varying(16) DEFAULT ''::character varying NOT NULL,
    name_first character varying(64) DEFAULT ''::character varying NOT NULL,
    name_last character varying(64) DEFAULT ''::character varying NOT NULL,
    email character varying(128),
    login_num integer DEFAULT 0 NOT NULL,
    "password" character varying(32) DEFAULT ''::character varying NOT NULL,
    created timestamp without time zone
);


ALTER TABLE public.users OWNER TO pipeline;

--
-- Name: workflow; Type: TABLE; Schema: public; Owner: pipeline; Tablespace: 
--

CREATE TABLE workflow (
    project_id integer NOT NULL,
    task_id smallint NOT NULL,
    user_id integer NOT NULL,
    status_id smallint NOT NULL,
    duration numeric(7,3) DEFAULT 0.0 NOT NULL,
    created timestamp without time zone,
    archived boolean DEFAULT false NOT NULL
);


ALTER TABLE public.workflow OWNER TO pipeline;

--
-- Name: group_id_pk; Type: CONSTRAINT; Schema: public; Owner: pipeline; Tablespace: 
--

ALTER TABLE ONLY groups
    ADD CONSTRAINT group_id_pk PRIMARY KEY (group_id);


--
-- Name: group_name_ndx; Type: CONSTRAINT; Schema: public; Owner: pipeline; Tablespace: 
--

ALTER TABLE ONLY groups
    ADD CONSTRAINT group_name_ndx UNIQUE (group_name);


--
-- Name: project_id_ndx; Type: CONSTRAINT; Schema: public; Owner: pipeline; Tablespace: 
--

ALTER TABLE ONLY project
    ADD CONSTRAINT project_id_ndx PRIMARY KEY (project_id);


--
-- Name: project_uniq_ndx; Type: CONSTRAINT; Schema: public; Owner: pipeline; Tablespace: 
--

ALTER TABLE ONLY project
    ADD CONSTRAINT project_uniq_ndx UNIQUE (user_id, name);


--
-- Name: task_pk_ndx; Type: CONSTRAINT; Schema: public; Owner: pipeline; Tablespace: 
--

ALTER TABLE ONLY task
    ADD CONSTRAINT task_pk_ndx PRIMARY KEY (task_id);


--
-- Name: task_status_id_ndx; Type: CONSTRAINT; Schema: public; Owner: pipeline; Tablespace: 
--

ALTER TABLE ONLY task_status
    ADD CONSTRAINT task_status_id_ndx PRIMARY KEY (status_id);


--
-- Name: task_status_name_ndx; Type: CONSTRAINT; Schema: public; Owner: pipeline; Tablespace: 
--

ALTER TABLE ONLY task_status
    ADD CONSTRAINT task_status_name_ndx UNIQUE (name);


--
-- Name: task_uniq_ndx; Type: CONSTRAINT; Schema: public; Owner: pipeline; Tablespace: 
--

ALTER TABLE ONLY task
    ADD CONSTRAINT task_uniq_ndx UNIQUE (name);


--
-- Name: user_groups_pk; Type: CONSTRAINT; Schema: public; Owner: pipeline; Tablespace: 
--

ALTER TABLE ONLY user_groups
    ADD CONSTRAINT user_groups_pk PRIMARY KEY (group_id, user_id);


--
-- Name: user_id; Type: CONSTRAINT; Schema: public; Owner: pipeline; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT user_id PRIMARY KEY (user_id);


--
-- Name: username_ndx; Type: CONSTRAINT; Schema: public; Owner: pipeline; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT username_ndx UNIQUE (username);


--
-- Name: workflow_pk; Type: CONSTRAINT; Schema: public; Owner: pipeline; Tablespace: 
--

ALTER TABLE ONLY workflow
    ADD CONSTRAINT workflow_pk PRIMARY KEY (project_id, task_id);


--
-- Name: project_user_fk; Type: FK CONSTRAINT; Schema: public; Owner: pipeline
--

ALTER TABLE ONLY project
    ADD CONSTRAINT project_user_fk FOREIGN KEY (user_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: user_groups_group_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: pipeline
--

ALTER TABLE ONLY user_groups
    ADD CONSTRAINT user_groups_group_id_fk FOREIGN KEY (group_id) REFERENCES groups(group_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: user_groups_user_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: pipeline
--

ALTER TABLE ONLY user_groups
    ADD CONSTRAINT user_groups_user_id_fk FOREIGN KEY (user_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: workflow_project_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: pipeline
--

ALTER TABLE ONLY workflow
    ADD CONSTRAINT workflow_project_id_fk FOREIGN KEY (project_id) REFERENCES project(project_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: workflow_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: pipeline
--

ALTER TABLE ONLY workflow
    ADD CONSTRAINT workflow_status_id_fk FOREIGN KEY (status_id) REFERENCES task_status(status_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: workflow_task_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: pipeline
--

ALTER TABLE ONLY workflow
    ADD CONSTRAINT workflow_task_id_fk FOREIGN KEY (task_id) REFERENCES task(task_id) ON UPDATE CASCADE ON DELETE CASCADE;


CREATE TABLE cachemd5
(
  id serial NOT NULL,
  project_id integer NOT NULL,
  task_name character varying(16) NOT NULL DEFAULT ''::character varying,
  crc character(32),
  CONSTRAINT cachemd5_pk_ndx PRIMARY KEY (id),
  CONSTRAINT cachemd5_fk_ndx FOREIGN KEY (project_id)
      REFERENCES project (project_id) MATCH SIMPLE
      ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT cachemd5_uniq_ndx UNIQUE (project_id, task_name)
)
WITHOUT OIDS;
ALTER TABLE cachemd5 OWNER TO pipeline;

-- Index: cachemd5_crc_ndx

-- DROP INDEX cachemd5_crc_ndx;

CREATE INDEX cachemd5_crc_ndx ON cachemd5 USING hash (crc);

CREATE TYPE t_history as (task_id smallint,  status_id smallint, duration numeric(7,3) , created timestamp without time zone);

CREATE OR REPLACE FUNCTION history(int) RETURNS SETOF t_history
AS $$
select task_id, status_id, duration, created from workflow where project_id = $1
union
select task_id, status_id, duration, created from workflow_history where project_id = $1
$$
LANGUAGE SQL;


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--



REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--


--
-- PostgreSQL database dump
--

\restrict tncBHb2VvO7rksKduBxrc3Xpj4U0fWJVD2A8T7RZXhfsV7fWVcelAogeWNHuryI

-- Dumped from database version 16.15
-- Dumped by pg_dump version 16.15

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: application; Type: TABLE; Schema: public; Owner: talentflow
--

CREATE TABLE public.application (
    id integer NOT NULL,
    job_id integer NOT NULL,
    candidate_id integer NOT NULL,
    status character varying(32) NOT NULL,
    created_at timestamp with time zone NOT NULL
);



--
-- Name: application_id_seq; Type: SEQUENCE; Schema: public; Owner: talentflow
--

CREATE SEQUENCE public.application_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



--
-- Name: application_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: talentflow
--

ALTER SEQUENCE public.application_id_seq OWNED BY public.application.id;


--
-- Name: candidate; Type: TABLE; Schema: public; Owner: talentflow
--

CREATE TABLE public.candidate (
    id integer NOT NULL,
    full_name character varying(160) NOT NULL,
    email character varying(254) NOT NULL,
    phone character varying(40),
    resume_key character varying(1024),
    created_at timestamp with time zone NOT NULL
);



--
-- Name: candidate_id_seq; Type: SEQUENCE; Schema: public; Owner: talentflow
--

CREATE SEQUENCE public.candidate_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



--
-- Name: candidate_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: talentflow
--

ALTER SEQUENCE public.candidate_id_seq OWNED BY public.candidate.id;


--
-- Name: job; Type: TABLE; Schema: public; Owner: talentflow
--

CREATE TABLE public.job (
    id integer NOT NULL,
    title character varying(160) NOT NULL,
    department character varying(120),
    description text NOT NULL,
    status character varying(24) NOT NULL,
    created_by integer NOT NULL,
    created_at timestamp with time zone NOT NULL
);



--
-- Name: job_id_seq; Type: SEQUENCE; Schema: public; Owner: talentflow
--

CREATE SEQUENCE public.job_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



--
-- Name: job_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: talentflow
--

ALTER SEQUENCE public.job_id_seq OWNED BY public.job.id;


--
-- Name: user; Type: TABLE; Schema: public; Owner: talentflow
--

CREATE TABLE public."user" (
    id integer NOT NULL,
    email character varying(254) NOT NULL,
    password_hash character varying(255) NOT NULL,
    role character varying(24) NOT NULL,
    created_at timestamp with time zone NOT NULL
);



--
-- Name: user_id_seq; Type: SEQUENCE; Schema: public; Owner: talentflow
--

CREATE SEQUENCE public.user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



--
-- Name: user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: talentflow
--

ALTER SEQUENCE public.user_id_seq OWNED BY public."user".id;


--
-- Name: application id; Type: DEFAULT; Schema: public; Owner: talentflow
--

ALTER TABLE ONLY public.application ALTER COLUMN id SET DEFAULT nextval('public.application_id_seq'::regclass);


--
-- Name: candidate id; Type: DEFAULT; Schema: public; Owner: talentflow
--

ALTER TABLE ONLY public.candidate ALTER COLUMN id SET DEFAULT nextval('public.candidate_id_seq'::regclass);


--
-- Name: job id; Type: DEFAULT; Schema: public; Owner: talentflow
--

ALTER TABLE ONLY public.job ALTER COLUMN id SET DEFAULT nextval('public.job_id_seq'::regclass);


--
-- Name: user id; Type: DEFAULT; Schema: public; Owner: talentflow
--

ALTER TABLE ONLY public."user" ALTER COLUMN id SET DEFAULT nextval('public.user_id_seq'::regclass);


--
-- Data for Name: application; Type: TABLE DATA; Schema: public; Owner: talentflow
--

COPY public.application (id, job_id, candidate_id, status, created_at) FROM stdin;
\.


--
-- Data for Name: candidate; Type: TABLE DATA; Schema: public; Owner: talentflow
--

COPY public.candidate (id, full_name, email, phone, resume_key, created_at) FROM stdin;
\.


--
-- Data for Name: job; Type: TABLE DATA; Schema: public; Owner: talentflow
--

COPY public.job (id, title, department, description, status, created_by, created_at) FROM stdin;
\.


--
-- Data for Name: user; Type: TABLE DATA; Schema: public; Owner: talentflow
--

COPY public."user" (id, email, password_hash, role, created_at) FROM stdin;
1	test@example.com	scrypt:32768:8:1$7qLWB5zFIebJQNYT$9873a52744ab41cb4e2f4bd9632589c89124393e1b2151ec93c4a71271b5f813c98ea753d741f061d665f70c5b9cb7975c9d5070aecc06c547b6ca9aad707a59	recruiter	2026-10-30 05:54:41.368375+00
2	laxmireddy870@gmail.com	scrypt:32768:8:1$nQaxKt8KZOcvjRjL$5fef9bc77897acbb57ee661cbd8a7e67648dc205369735d5a92231193fd691380cdc61a3f5d7494d064688742885f43dad090d9a3de0ea818c399f1aabdaa850	recruiter	2026-10-30 06:59:36.99474+00
\.


--
-- Name: application_id_seq; Type: SEQUENCE SET; Schema: public; Owner: talentflow
--

SELECT pg_catalog.setval('public.application_id_seq', 1, false);


--
-- Name: candidate_id_seq; Type: SEQUENCE SET; Schema: public; Owner: talentflow
--

SELECT pg_catalog.setval('public.candidate_id_seq', 1, false);


--
-- Name: job_id_seq; Type: SEQUENCE SET; Schema: public; Owner: talentflow
--

SELECT pg_catalog.setval('public.job_id_seq', 1, false);


--
-- Name: user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: talentflow
--

SELECT pg_catalog.setval('public.user_id_seq', 2, true);


--
-- Name: application application_pkey; Type: CONSTRAINT; Schema: public; Owner: talentflow
--

ALTER TABLE ONLY public.application
    ADD CONSTRAINT application_pkey PRIMARY KEY (id);


--
-- Name: candidate candidate_pkey; Type: CONSTRAINT; Schema: public; Owner: talentflow
--

ALTER TABLE ONLY public.candidate
    ADD CONSTRAINT candidate_pkey PRIMARY KEY (id);


--
-- Name: job job_pkey; Type: CONSTRAINT; Schema: public; Owner: talentflow
--

ALTER TABLE ONLY public.job
    ADD CONSTRAINT job_pkey PRIMARY KEY (id);


--
-- Name: application uq_application_job_candidate; Type: CONSTRAINT; Schema: public; Owner: talentflow
--

ALTER TABLE ONLY public.application
    ADD CONSTRAINT uq_application_job_candidate UNIQUE (job_id, candidate_id);


--
-- Name: user user_pkey; Type: CONSTRAINT; Schema: public; Owner: talentflow
--

ALTER TABLE ONLY public."user"
    ADD CONSTRAINT user_pkey PRIMARY KEY (id);


--
-- Name: ix_application_candidate_id; Type: INDEX; Schema: public; Owner: talentflow
--

CREATE INDEX ix_application_candidate_id ON public.application USING btree (candidate_id);


--
-- Name: ix_application_job_id; Type: INDEX; Schema: public; Owner: talentflow
--

CREATE INDEX ix_application_job_id ON public.application USING btree (job_id);


--
-- Name: ix_candidate_email; Type: INDEX; Schema: public; Owner: talentflow
--

CREATE INDEX ix_candidate_email ON public.candidate USING btree (email);


--
-- Name: ix_user_email; Type: INDEX; Schema: public; Owner: talentflow
--

CREATE UNIQUE INDEX ix_user_email ON public."user" USING btree (email);


--
-- Name: application application_candidate_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: talentflow
--

ALTER TABLE ONLY public.application
    ADD CONSTRAINT application_candidate_id_fkey FOREIGN KEY (candidate_id) REFERENCES public.candidate(id);


--
-- Name: application application_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: talentflow
--

ALTER TABLE ONLY public.application
    ADD CONSTRAINT application_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.job(id);


--
-- Name: job job_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: talentflow
--

ALTER TABLE ONLY public.job
    ADD CONSTRAINT job_created_by_fkey FOREIGN KEY (created_by) REFERENCES public."user"(id);


--
-- PostgreSQL database dump complete
--

\unrestrict tncBHb2VvO7rksKduBxrc3Xpj4U0fWJVD2A8T7RZXhfsV7fWVcelAogeWNHuryI

